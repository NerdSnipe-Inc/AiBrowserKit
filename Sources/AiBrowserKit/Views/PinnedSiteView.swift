#if canImport(AppKit)
import SwiftUI
import WebKit

/// Full-height view for a pinned site, shown when the user selects it in the sidebar.
/// Uses PinnedSiteWebViewCache so the page persists when switching sidebar items.
public struct PinnedSiteView: View {
    public let site: PinnedSite
    @Environment(BrowserEnvironment.self) private var browserEnv

    @State private var isLocalhostReachable: Bool? = nil
    @State private var refreshTimer: Timer?
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

    public init(site: PinnedSite) {
        self.site = site
    }

    private var cached: (webView: WKWebView, state: WebViewState) {
        browserEnv.webViewCache.entry(for: site)
    }
    private var state: WebViewState { cached.state }
    private var webView: WKWebView { cached.webView }

    public var body: some View {
        VStack(spacing: 0) {
            navBar

            if state.isLoading {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * state.estimatedProgress, height: 2)
                        .animation(.linear(duration: 0.2), value: state.estimatedProgress)
                }
                .frame(height: 2)
            } else {
                Divider().opacity(0.1)
            }

            if let error = state.error {
                errorView(error)
            } else {
                WebViewRepresentable(webView: webView)
            }
        }
        .onAppear {
            if site.isLocalhost { checkLocalhostReachability() }
            setupAutoRefresh()
        }
        .onDisappear { stopAutoRefresh() }
        .sheet(isPresented: $showEditSheet) {
            PinnedSiteEditorSheet(mode: .edit(site))
        }
        .alert("Remove \"\(site.name)\"?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                browserEnv.webViewCache.evict(id: site.id)
                browserEnv.favicons.evict(itemID: site.id)
                browserEnv.pinnedSites.removeSite(id: site.id)
            }
        } message: {
            Text("This will remove the item from your sidebar. You can always add it again later.")
        }
    }

    private var navBar: some View {
        HStack(spacing: 8) {
            // Color dot
            if let c = site.color {
                Circle()
                    .fill(Color(red: c.red, green: c.green, blue: c.blue))
                    .frame(width: 8, height: 8)
            }

            Text(site.name)
                .font(.headline)
                .lineLimit(1)

            // Localhost status dot
            if site.isLocalhost {
                Circle()
                    .fill(localhostColor)
                    .frame(width: 6, height: 6)
                    .help(localhostHelp)
            }

            Spacer()

            Text(displayURL)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            HStack(spacing: 2) {
                compactButton(state.themeOverride.icon, enabled: true) {
                    state.themeOverride = state.themeOverride.next
                    webView.appearance = state.themeOverride.nsAppearance
                    webView.reload()
                }
                .help(state.themeOverride.label)

                compactButton("chevron.left", enabled: state.canGoBack) { webView.goBack() }
                compactButton("chevron.right", enabled: state.canGoForward) { webView.goForward() }
                compactButton("arrow.clockwise", enabled: true) {
                    if let url = site.url { webView.load(URLRequest(url: url)) }
                }
                compactButton("safari", enabled: true) {
                    if let url = state.currentURL ?? site.url { NSWorkspace.shared.open(url) }
                }

                Divider().frame(height: 14).opacity(0.3)

                compactButton("pencil", enabled: true) { showEditSheet = true }
                    .help("Edit")
                compactButton("trash", enabled: true) { showDeleteConfirmation = true }
                    .help("Remove from sidebar")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var displayURL: String {
        guard let url = state.currentURL ?? site.url else { return site.urlString }
        var str = url.absoluteString
        if str.hasPrefix("https://") { str = String(str.dropFirst(8)) }
        if str.hasPrefix("http://") { str = String(str.dropFirst(7)) }
        if str.hasSuffix("/") { str = String(str.dropLast()) }
        return str
    }

    private var localhostColor: Color {
        switch isLocalhostReachable {
        case .some(true): .green
        case .some(false): .red.opacity(0.5)
        case .none: .secondary.opacity(0.3)
        }
    }

    private var localhostHelp: String {
        switch isLocalhostReachable {
        case .some(true): "Server is running"
        case .some(false): "Server not reachable"
        case .none: "Checking server..."
        }
    }

    private func checkLocalhostReachability() {
        guard let url = site.url else { return }
        Task {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3
            request.httpMethod = "HEAD"
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                isLocalhostReachable = response as? HTTPURLResponse != nil
            } catch {
                isLocalhostReachable = false
            }
        }
    }

    private func setupAutoRefresh() {
        guard let seconds = site.autoRefreshSeconds, seconds > 0 else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: true) { _ in
            MainActor.assumeIsolated {
                if let url = site.url { webView.load(URLRequest(url: url)) }
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Failed to Load")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Button("Try Again") {
                if let url = site.url { webView.load(URLRequest(url: url)) }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func compactButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(enabled ? Color.primary : Color.primary.opacity(0.25))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
#endif
