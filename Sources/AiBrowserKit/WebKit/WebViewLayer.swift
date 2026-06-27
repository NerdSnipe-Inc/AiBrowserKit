import SwiftUI
import WebKit
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

// MARK: - ScreenshotDestination

#if canImport(AppKit)
public enum ScreenshotDestination: Sendable { case clipboard, file, hostClipboard }

@MainActor
public func deliverScreenshot(_ image: NSImage, to destination: ScreenshotDestination) {
    switch destination {
    case .clipboard:
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    case .file:
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "screenshot.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
    case .hostClipboard:
        break
    }
}
#endif

// MARK: - WebViewThemeOverride

public enum WebViewThemeOverride: String, Sendable {
    case system
    case light
    case dark

    public var next: WebViewThemeOverride {
        switch self {
        case .system: .light
        case .light: .dark
        case .dark: .system
        }
    }

    public var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    public var label: String {
        switch self {
        case .system: "Follow system"
        case .light: "Light mode"
        case .dark: "Dark mode"
        }
    }

    #if canImport(AppKit)
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
    #endif
}

// MARK: - WebViewState

/// Observable state for a single WKWebView instance.
@MainActor
@Observable
public final class WebViewState {
    public var currentURL: URL?
    public var pageTitle: String = ""
    public var isLoading: Bool = false
    public var estimatedProgress: Double = 0
    public var canGoBack: Bool = false
    public var canGoForward: Bool = false
    public var isSecure: Bool = false
    public var hasOnlySecureContent: Bool = false
    public var error: String?
    public var themeOverride: WebViewThemeOverride = .system

    public init() {}
}

// MARK: - WebViewStore

/// Shared WebKit configuration for all in-app web views.
@MainActor
public enum WebViewStore {
    public static let dataStore = WKWebsiteDataStore.default()

    #if canImport(AppKit)
    /// Matches Safari on macOS 15.5.
    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"
    #else
    /// Matches Safari on iOS 18.5.
    public static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"
    #endif

    public static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.defaultWebpagePreferences.preferredContentMode = .desktop

        return config
    }
}

// MARK: - WebViewRepresentable

#if canImport(AppKit)
public struct WebViewRepresentable: NSViewRepresentable {
    public let webView: WKWebView

    public init(webView: WKWebView) {
        self.webView = webView
    }

    public func makeNSView(context: Context) -> WKWebView { webView }
    public func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#else
public struct WebViewRepresentable: UIViewRepresentable {
    public let webView: WKWebView

    public init(webView: WKWebView) {
        self.webView = webView
    }

    public func makeUIView(context: Context) -> WKWebView { webView }
    public func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif

// MARK: - WebViewFactory

private let consoleInterceptScript = """
(function() {
    var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.aiBrowserConsole;
    if (!h) return;
    ['log','info','warn','error','debug'].forEach(function(lvl) {
        var orig = console[lvl];
        console[lvl] = function() {
            var msg = Array.prototype.slice.call(arguments).map(function(a) {
                try { return typeof a === 'object' ? JSON.stringify(a) : String(a); } catch(e) { return String(a); }
            }).join(' ');
            try { h.postMessage({ level: lvl, message: msg }); } catch(_) {}
            if (orig) orig.apply(console, arguments);
        };
    });
})();
"""

@MainActor
public enum WebViewFactory {
    public static func makeWebView(state: WebViewState, consoleStore: ConsoleLogStore? = nil) -> WKWebView {
        let config = WebViewStore.makeConfiguration()

        let coordinator = WebViewCoordinator(state: state, consoleStore: consoleStore)

        let stealthScript = WKUserScript(
            source: StealthScript.source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(stealthScript)

        if consoleStore != nil {
            let script = WKUserScript(source: consoleInterceptScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(script)
            config.userContentController.add(coordinator, name: "aiBrowserConsole")
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = WebViewStore.userAgent
        webView.allowsBackForwardNavigationGestures = true
        #if canImport(AppKit)
        webView.allowsMagnification = true
        #endif

        coordinator.webView = webView
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator

        objc_setAssociatedObject(webView, &WebViewCoordinator.associatedKey, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        coordinator.observeWebView(webView)

        return webView
    }
}

// MARK: - WebViewCoordinator

@MainActor
public final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    nonisolated(unsafe) public static var associatedKey: UInt8 = 0

    private let state: WebViewState
    private let consoleStore: ConsoleLogStore?
    weak var webView: WKWebView?
    private var observations: [NSKeyValueObservation] = []

    init(state: WebViewState, consoleStore: ConsoleLogStore? = nil) {
        self.state = state
        self.consoleStore = consoleStore
    }

    func observeWebView(_ webView: WKWebView) {
        observations = [
            webView.observe(\.isLoading) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.isLoading = wv.isLoading }
            },
            webView.observe(\.estimatedProgress) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.estimatedProgress = wv.estimatedProgress }
            },
            webView.observe(\.canGoBack) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.canGoBack = wv.canGoBack }
            },
            webView.observe(\.canGoForward) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.canGoForward = wv.canGoForward }
            },
            webView.observe(\.title) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.pageTitle = wv.title ?? "" }
            },
            webView.observe(\.url) { [weak self] wv, _ in
                MainActor.assumeIsolated {
                    self?.state.currentURL = wv.url
                    self?.state.isSecure = wv.url?.scheme == "https"
                }
            },
            webView.observe(\.hasOnlySecureContent) { [weak self] wv, _ in
                MainActor.assumeIsolated { self?.state.hasOnlySecureContent = wv.hasOnlySecureContent }
            },
        ]
    }

    // MARK: - WKScriptMessageHandler

    nonisolated public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // WKScriptMessage properties are @MainActor in the new SDK; WKWebView always
        // calls this on the main thread, so assumeIsolated is safe here.
        MainActor.assumeIsolated {
            guard message.name == "aiBrowserConsole",
                  let body = message.body as? [String: Any],
                  let levelRaw = body["level"] as? String,
                  let text = body["message"] as? String
            else { return }
            let level = ConsoleLevel(rawValue: levelRaw) ?? .log
            let source = message.frameInfo.request.url?.absoluteString
            consoleStore?.append(ConsoleEntry(level: level, message: text, source: source))
        }
    }

    // MARK: - WKNavigationDelegate

    nonisolated public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        let url = await MainActor.run { navigationAction.request.url }
        let hasTarget = await MainActor.run { navigationAction.targetFrame != nil }
        guard let url else { return .allow }

        if !hasTarget {
            _ = await MainActor.run { webView.load(URLRequest(url: url)) }
            return .cancel
        }
        return .allow
    }

    nonisolated public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let message = error.localizedDescription
        MainActor.assumeIsolated { self.state.error = message }
    }

    nonisolated public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        let message = error.localizedDescription
        MainActor.assumeIsolated { self.state.error = message }
    }

    nonisolated public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { self.state.error = nil }
    }

    // MARK: - WKUIDelegate

    nonisolated public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        MainActor.assumeIsolated {
            if let url = navigationAction.request.url {
                _ = webView.load(URLRequest(url: url))
            }
        }
        return nil
    }

    nonisolated public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async {
        #if canImport(AppKit)
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        #else
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                guard let vc = self.rootViewController() else { cont.resume(); return }
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in cont.resume() })
                vc.present(alert, animated: true)
            }
        }
        #endif
    }

    nonisolated public func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async -> Bool {
        #if canImport(AppKit)
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            return alert.runModal() == .alertFirstButtonReturn
        }
        #else
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            Task { @MainActor in
                guard let vc = self.rootViewController() else { cont.resume(returning: false); return }
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in cont.resume(returning: true) })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in cont.resume(returning: false) })
                vc.present(alert, animated: true)
            }
        }
        #endif
    }

    nonisolated public func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo
    ) async -> String? {
        #if canImport(AppKit)
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = prompt
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            input.stringValue = defaultText ?? ""
            alert.accessoryView = input
            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? input.stringValue : nil
        }
        #else
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            Task { @MainActor in
                guard let vc = self.rootViewController() else { cont.resume(returning: nil); return }
                let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
                alert.addTextField { tf in tf.text = defaultText }
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    cont.resume(returning: alert.textFields?.first?.text)
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    cont.resume(returning: nil)
                })
                vc.present(alert, animated: true)
            }
        }
        #endif
    }

    // MARK: - iOS helpers

    #if !canImport(AppKit)
    @MainActor
    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
    #endif
}
