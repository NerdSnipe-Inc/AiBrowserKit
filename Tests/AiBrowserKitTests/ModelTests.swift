import Foundation
import Testing
@testable import AiBrowserKit

@Suite("Model Codable & computed properties")
struct ModelTests {

    @Test("BrowserBookmark round-trips without folderID")
    func bookmarkRoundTrip() throws {
        let original = BrowserBookmark(id: "b1", title: "Example", urlString: "https://example.com")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserBookmark.self, from: data)
        #expect(decoded.id == "b1")
        #expect(decoded.title == "Example")
        #expect(decoded.urlString == "https://example.com")
        #expect(decoded.folderID == nil)
        #expect(decoded.displayHost == "example.com")
    }

    @Test("BrowserBookmark decodes missing folderID from legacy JSON")
    func bookmarkLegacyDecode() throws {
        let json = """
        {"id":"legacy","title":"Old","urlString":"https://old.test","createdAt":"2024-01-01T00:00:00Z"}
        """
        let decoded = try JSONDecoder().decode(BrowserBookmark.self, from: json.data(using: .utf8)!)
        #expect(decoded.folderID == nil)
        #expect(decoded.createdAt == "2024-01-01T00:00:00Z")
    }

    @Test("BookmarkFolder encodes sort order")
    func folderRoundTrip() throws {
        let folder = BookmarkFolder(id: "f1", name: "Work", sortOrder: 2)
        let data = try JSONEncoder().encode(folder)
        let decoded = try JSONDecoder().decode(BookmarkFolder.self, from: data)
        #expect(decoded.name == "Work")
        #expect(decoded.sortOrder == 2)
    }

    @Test("PinnedSite localhost detection")
    func pinnedSiteLocalhost() {
        let local = PinnedSite(name: "Dev", urlString: "http://localhost:3000")
        let remote = PinnedSite(name: "Web", urlString: "https://example.com")
        #expect(local.isLocalhost)
        #expect(!remote.isLocalhost)
    }

    @Test("PinnedSite color hex parsing")
    func pinnedSiteColor() {
        let site = PinnedSite(name: "Colored", urlString: "https://x.com", colorHex: "#FF0000")
        let rgb = site.color
        #expect(rgb != nil)
        #expect(rgb!.red == 1.0)
        #expect(rgb!.green == 0.0)
        #expect(rgb!.blue == 0.0)
    }

    @Test("PinnedSiteStoreData round-trip")
    func pinnedStoreDataRoundTrip() throws {
        let site = PinnedSite(id: "s1", name: "Docs", urlString: "https://docs.example.com")
        let group = PinnedSiteGroup(id: "g1", name: "Dev")
        let envelope = PinnedSiteStoreData(sites: [site], groups: [group])
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(PinnedSiteStoreData.self, from: data)
        #expect(decoded.sites.count == 1)
        #expect(decoded.groups.count == 1)
        #expect(decoded.sites[0].name == "Docs")
    }
}

@Suite("WebViewThemeOverride")
struct WebViewThemeTests {

    @Test("Theme cycles system → light → dark → system")
    func themeCycle() {
        #expect(WebViewThemeOverride.system.next == .light)
        #expect(WebViewThemeOverride.light.next == .dark)
        #expect(WebViewThemeOverride.dark.next == .system)
    }

    @Test("Theme icons and labels are non-empty")
    func themeMetadata() {
        for theme in [WebViewThemeOverride.system, .light, .dark] {
            #expect(!theme.icon.isEmpty)
            #expect(!theme.label.isEmpty)
        }
    }
}
