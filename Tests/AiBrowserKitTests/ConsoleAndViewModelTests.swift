import Foundation
import Testing
@testable import AiBrowserKit

@Suite("ConsoleLogStore")
@MainActor
struct ConsoleLogStoreTests {

    @Test("Append and clear entries")
    func appendAndClear() {
        let store = ConsoleLogStore()
        store.append(ConsoleEntry(level: .log, message: "hello", source: nil))
        store.append(ConsoleEntry(level: .error, message: "boom", source: "main.js"))
        #expect(store.entries.count == 2)
        #expect(store.entries[1].level == .error)

        store.clear()
        #expect(store.entries.isEmpty)
    }

    @Test("Ring buffer caps at 500 entries")
    func ringBufferCap() {
        let store = ConsoleLogStore()
        for i in 0..<520 {
            store.append(ConsoleEntry(level: .log, message: "line \(i)", source: nil))
        }
        #expect(store.entries.count == 500)
        #expect(store.entries.first?.message == "line 20")
        #expect(store.entries.last?.message == "line 519")
    }
}

#if canImport(AppKit)
@Suite("BrowserViewModel tab management")
@MainActor
struct BrowserViewModelTests {

    @Test("Starts with one blank tab selected")
    func initialState() {
        let vm = BrowserViewModel()
        #expect(vm.tabs.count == 1)
        #expect(vm.selectedTab != nil)
        #expect(vm.selectedTab?.isBlank == true)
    }

    @Test("newTab adds tab and selects it")
    func newTab() {
        let vm = BrowserViewModel()
        let firstID = vm.selectedTabID
        vm.newTab()
        #expect(vm.tabs.count == 2)
        #expect(vm.selectedTabID != firstID)
    }

    @Test("closeTab removes tab and reselects when needed")
    func closeTab() {
        let vm = BrowserViewModel()
        vm.newTab()
        let closingID = vm.selectedTabID!
        vm.closeTab(closingID)
        #expect(vm.tabs.count == 1)
        #expect(vm.selectedTabID != closingID)
    }

    @Test("Cannot close last remaining tab")
    func cannotCloseLastTab() {
        let vm = BrowserViewModel()
        let only = vm.tabs[0].id
        vm.closeTab(only)
        #expect(vm.tabs.count == 1)
    }
}

@Suite("PinnedSiteWebViewCache")
@MainActor
struct PinnedSiteWebViewCacheTests {

    @Test("Returns same web view for site id")
    func cachesByID() {
        let cache = PinnedSiteWebViewCache()
        let site = PinnedSite(id: "cache-1", name: "Ex", urlString: "https://example.com")
        let first = cache.entry(for: site).webView
        let second = cache.entry(for: site).webView
        #expect(first === second)
    }

    @Test("Evict removes cached entry")
    func evict() {
        let cache = PinnedSiteWebViewCache()
        let site = PinnedSite(id: "cache-2", name: "Ex", urlString: "https://example.com")
        let first = cache.entry(for: site).webView
        cache.evict(id: site.id)
        let second = cache.entry(for: site).webView
        #expect(first !== second)
    }
}
#endif
