import Foundation
import Testing
@testable import AiBrowserKit

#if canImport(AppKit)
import WebKit

@Suite("WebViewFactory — live WKWebView", .enabled(if: IntegrationTestGate.isEnabled), .serialized)
@MainActor
struct WebViewIntegrationTests {

    @Test("makeWebView loads https://example.com")
    func loadsExampleCom() async {
        let state = WebViewState()
        let webView = WebViewFactory.makeWebView(state: state)
        webView.load(URLRequest(url: URL(string: "https://example.com")!))

        let loaded = await TestSupport.waitUntil {
            state.currentURL?.host()?.contains("example.com") == true && !state.isLoading
        }
        #expect(loaded)
        #expect(state.pageTitle.isEmpty == false || state.currentURL != nil)
    }

    @Test("Console store receives log messages from page JS")
    func consoleCapture() async throws {
        let store = ConsoleLogStore()
        let state = WebViewState()
        let webView = WebViewFactory.makeWebView(state: state, consoleStore: store)

        let html = """
        <html><body><script>console.log('AiBrowserKit integration probe');</script></body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://test.local"))

        let captured = await TestSupport.waitUntil(timeout: 10) {
            store.entries.contains { $0.message.contains("integration probe") }
        }
        #expect(captured)
    }

    @Test("WebViewStore user agent is non-empty Safari-like string")
    func userAgentPresent() {
        #expect(!WebViewStore.userAgent.isEmpty)
        #expect(WebViewStore.userAgent.contains("AppleWebKit"))
    }

    @Test("makeConfiguration enables JavaScript")
    func configurationDefaults() {
        let config = WebViewStore.makeConfiguration()
        #expect(config.defaultWebpagePreferences.allowsContentJavaScript)
    }
}

@Suite("BrowserTab — live navigation", .enabled(if: IntegrationTestGate.isEnabled), .serialized)
@MainActor
struct BrowserTabIntegrationTests {

    @Test("navigate(to:) loads resolved https URL")
    func navigateDomain() async {
        let tab = BrowserTab()
        tab.navigate(to: "example.com")

        let loaded = await TestSupport.waitUntil {
            tab.webView.url?.host()?.contains("example.com") == true
        }
        #expect(loaded)
        #expect(tab.isBlank == false)
    }

    @Test("navigate(to:) search query reaches Google")
    func navigateSearch() async {
        let tab = BrowserTab()
        tab.navigate(to: "unique browser kit query xyz")

        let loaded = await TestSupport.waitUntil {
            tab.webView.url?.host()?.contains("google.com") == true
        }
        #expect(loaded)
    }
}

@Suite("FaviconService — network", .enabled(if: IntegrationTestGate.isEnabled), .serialized)
@MainActor
struct FaviconIntegrationTests {

    @Test("fetchFavicon caches PNG for example.com")
    func fetchExampleFavicon() async {
        let dir = TestSupport.makeStorageDirectory()
        defer { TestSupport.removeStorageDirectory(dir) }

        let service = FaviconService(storageDirectory: dir)
        let image = await service.fetchFavicon(for: "https://example.com", itemID: "example-com")
        #expect(image != nil)
        #expect(service.cachedImage(for: "example-com") != nil)
    }
}

@Suite("BrowserEnvironment — colocated storage", .enabled(if: IntegrationTestGate.isEnabled), .serialized)
@MainActor
struct BrowserEnvironmentIntegrationTests {

    @Test("shared storage directory round-trips bookmarks and pinned sites")
    func unifiedStorage() {
        let dir = TestSupport.makeStorageDirectory()
        defer { TestSupport.removeStorageDirectory(dir) }

        let env = BrowserEnvironment(storageDirectory: dir)
        env.bookmarks.add(title: "Env", urlString: "https://env.test")
        env.pinnedSites.addSite(PinnedSite(id: "env-pin", name: "Pin", urlString: "https://pin.test"))

        let reloaded = BrowserEnvironment(storageDirectory: dir)
        #expect(reloaded.bookmarks.bookmarks.count == 1)
        #expect(reloaded.pinnedSites.sites.count == 1)
    }
}
#endif
