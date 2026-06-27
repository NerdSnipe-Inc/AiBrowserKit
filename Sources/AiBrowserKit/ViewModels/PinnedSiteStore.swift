#if canImport(AppKit)
import Foundation

/// Manages persisted pinned sites and groups.
/// Stored as JSON in the configured storage directory (default: Application Support/AiBrowserKit/).
@MainActor
@Observable
public final class PinnedSiteStore {
    /// Persisted pinned sites.
    public var sites: [PinnedSite] = []
    /// Persisted pinned-site groups.
    public var groups: [PinnedSiteGroup] = []

    private let fileURL: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    /// Creates a pinned-site store and loads persisted data.
    ///
    /// - Parameter storageDirectory: Optional base directory for storage files.
    public init(storageDirectory: URL? = nil) {
        let dir = AiBrowserStorage.directory(custom: storageDirectory)
        self.fileURL = dir.appendingPathComponent("pinned_sites.json")
        if storageDirectory == nil {
            AiBrowserStorage.migratePinnedSitesIfNeeded(to: fileURL)
        }
        load()
    }

    // MARK: - Sites

    /// Adds a site while assigning the next available sort order.
    ///
    /// - Parameter site: Site to append.
    public func addSite(_ site: PinnedSite) {
        var s = site
        s = PinnedSite(
            id: site.id, name: site.name, urlString: site.urlString,
            iconName: site.iconName, useFavicon: site.useFavicon,
            colorHex: site.colorHex, groupID: site.groupID,
            autoRefreshSeconds: site.autoRefreshSeconds,
            sortOrder: sites.count
        )
        sites.append(s)
        save()
    }

    /// Updates an existing pinned site by identifier.
    ///
    /// - Parameter site: Updated site value.
    public func updateSite(_ site: PinnedSite) {
        if let idx = sites.firstIndex(where: { $0.id == site.id }) {
            sites[idx] = site
            save()
        }
    }

    /// Removes a pinned site by identifier.
    ///
    /// - Parameter id: Site identifier to remove.
    public func removeSite(id: String) {
        sites.removeAll { $0.id == id }
        save()
    }

    /// Looks up a pinned site by identifier.
    ///
    /// - Parameter id: Site identifier to query.
    /// - Returns: Matching site, if found.
    public func site(id: String) -> PinnedSite? {
        sites.first { $0.id == id }
    }

    /// Sites sorted by ascending `sortOrder`.
    public var visibleSites: [PinnedSite] {
        sites.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Groups

    /// Adds a group while assigning the next available sort order.
    ///
    /// - Parameter group: Group to append.
    public func addGroup(_ group: PinnedSiteGroup) {
        var g = group
        g = PinnedSiteGroup(id: group.id, name: group.name, iconName: group.iconName,
                            colorHex: group.colorHex, sortOrder: groups.count)
        groups.append(g)
        save()
    }

    /// Removes a group and clears that group assignment from member sites.
    ///
    /// - Parameter id: Group identifier to remove.
    public func removeGroup(id: String) {
        groups.removeAll { $0.id == id }
        for i in sites.indices where sites[i].groupID == id {
            sites[i] = PinnedSite(
                id: sites[i].id, name: sites[i].name, urlString: sites[i].urlString,
                iconName: sites[i].iconName, useFavicon: sites[i].useFavicon,
                colorHex: sites[i].colorHex, groupID: nil,
                autoRefreshSeconds: sites[i].autoRefreshSeconds, sortOrder: sites[i].sortOrder
            )
        }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let stored = try decoder.decode(PinnedSiteStoreData.self, from: data)
            sites = stored.sites
            groups = stored.groups
        } catch {
            sites = []
            groups = []
        }
    }

    private func save() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let stored = PinnedSiteStoreData(sites: sites, groups: groups)
        if let data = try? encoder.encode(stored) {
            try? data.write(to: fileURL)
        }
    }
}
#endif
