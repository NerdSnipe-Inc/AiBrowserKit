#if canImport(AppKit)
import WebKit

/// Caches WKWebView instances for pinned sites so pages persist across sidebar navigation.
@MainActor
public final class PinnedSiteWebViewCache {
    private var cache: [String: (webView: WKWebView, state: WebViewState)] = [:]

    /// Creates an empty pinned-site web view cache.
    public init() {}

    /// Returns (or creates) a cached WKWebView for the given pinned site.
    public func entry(for site: PinnedSite) -> (webView: WKWebView, state: WebViewState) {
        if let existing = cache[site.id] {
            return existing
        }
        let state = WebViewState()
        let webView = WebViewFactory.makeWebView(state: state)
        if let url = site.url {
            webView.load(URLRequest(url: url))
        }
        let entry = (webView: webView, state: state)
        cache[site.id] = entry
        return entry
    }

    /// Removes the cached web view for a site (call when deleting a pinned site).
    ///
    /// - Parameter id: Identifier of the pinned site to evict.
    public func evict(id: String) {
        cache.removeValue(forKey: id)
    }
}
#endif
