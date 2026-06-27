import Foundation
import Testing
@testable import AiBrowserKit

#if canImport(AppKit)
@Suite("PinnedSiteStore persistence", .serialized)
@MainActor
struct PinnedSiteStoreTests {

    private func makeStore() -> (PinnedSiteStore, URL) {
        let dir = TestSupport.makeStorageDirectory()
        return (PinnedSiteStore(storageDirectory: dir), dir)
    }

    @Test("Add site persists and reloads")
    func addSiteRoundTrip() {
        let (store, dir) = makeStore()
        defer { TestSupport.removeStorageDirectory(dir) }

        let site = PinnedSite(id: "pin-1", name: "Docs", urlString: "https://docs.test")
        store.addSite(site)
        #expect(store.sites.count == 1)

        let reloaded = PinnedSiteStore(storageDirectory: dir)
        #expect(reloaded.sites.count == 1)
        #expect(reloaded.sites[0].name == "Docs")
    }

    @Test("Update and remove site")
    func updateAndRemove() {
        let (store, dir) = makeStore()
        defer { TestSupport.removeStorageDirectory(dir) }

        store.addSite(PinnedSite(id: "pin-2", name: "Old", urlString: "https://old.test"))
        var updated = store.sites[0]
        updated.name = "New"
        store.updateSite(updated)
        #expect(store.sites[0].name == "New")

        store.removeSite(id: "pin-2")
        #expect(store.sites.isEmpty)
    }

    @Test("Group add removes sites from deleted group")
    func groupLifecycle() {
        let (store, dir) = makeStore()
        defer { TestSupport.removeStorageDirectory(dir) }

        store.addGroup(PinnedSiteGroup(id: "grp-1", name: "Dev"))
        store.addSite(PinnedSite(id: "pin-3", name: "Local", urlString: "http://localhost", groupID: "grp-1"))
        #expect(store.sites[0].groupID == "grp-1")

        store.removeGroup(id: "grp-1")
        #expect(store.groups.isEmpty)
        #expect(store.sites[0].groupID == nil)
    }

    @Test("visibleSites returns sorted by sortOrder (append order when adding)")
    func visibleSitesSort() {
        let (store, dir) = makeStore()
        defer { TestSupport.removeStorageDirectory(dir) }

        store.addSite(PinnedSite(id: "a", name: "First", urlString: "https://first.test", sortOrder: 99))
        store.addSite(PinnedSite(id: "b", name: "Second", urlString: "https://second.test", sortOrder: 1))
        // addSite assigns sortOrder = sites.count at insert time
        let names = store.visibleSites.map(\.name)
        #expect(names == ["First", "Second"])
    }
}
#endif
