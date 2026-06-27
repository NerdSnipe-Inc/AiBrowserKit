#if canImport(AppKit)
import Foundation
import WebKit

/// Model for a single browser tab.
@MainActor
@Observable
public final class BrowserTab: Identifiable {
    public let id: String
    public let state: WebViewState
    public let webView: WKWebView

    /// True until the user navigates — used to show the new tab landing page.
    public var isBlank: Bool = true

    public var title: String { state.pageTitle.isEmpty ? "New Tab" : state.pageTitle }
    public var displayURL: String { state.currentURL?.absoluteString ?? "" }
    public var isLoading: Bool { state.isLoading }

    public init(url: URL? = nil, consoleStore: ConsoleLogStore? = nil) {
        self.id = UUID().uuidString
        self.state = WebViewState()
        self.webView = WebViewFactory.makeWebView(state: state, consoleStore: consoleStore)
        if let url {
            isBlank = false
            webView.load(URLRequest(url: url))
        }
    }

    public func navigate(to urlString: String) {
        guard let url = BrowserURLResolver.resolve(input: urlString) else { return }
        isBlank = false
        webView.load(URLRequest(url: url))
    }

    public func goBack() { webView.goBack() }
    public func goForward() { webView.goForward() }
    public func reload() { webView.reload() }
    public func stopLoading() { webView.stopLoading() }

    public func cycleTheme() {
        state.themeOverride = state.themeOverride.next
        applyTheme()
    }

    public func applyTheme() {
        webView.appearance = state.themeOverride.nsAppearance
        webView.reload()
    }
}
#endif
