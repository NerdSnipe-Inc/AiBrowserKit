import Foundation

// MARK: - PinnedSiteGroup

public struct PinnedSiteGroup: Codable, Identifiable, Hashable, Sendable {
    /// Stable group identifier.
    public let id: String
    /// User-visible group name.
    public var name: String
    /// SF Symbol name representing the group.
    public var iconName: String
    /// Optional hex color string used for accent display.
    public var colorHex: String?
    /// Display order used for group sorting.
    public var sortOrder: Int

    /// Creates a pinned-site group.
    ///
    /// - Parameters:
    ///   - id: Stable identifier. Defaults to a new UUID string.
    ///   - name: User-visible group name.
    ///   - iconName: SF Symbol used for the group icon.
    ///   - colorHex: Optional six-digit hex color.
    ///   - sortOrder: Group ordering index.
    public init(
        id: String = UUID().uuidString,
        name: String,
        iconName: String = "folder",
        colorHex: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    /// Decoded RGB tuple from `colorHex`, when valid.
    public var color: (red: Double, green: Double, blue: Double)? {
        guard let hex = colorHex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")) else { return nil }
        guard hex.count == 6, let val = UInt64(hex, radix: 16) else { return nil }
        return (
            red: Double((val >> 16) & 0xFF) / 255.0,
            green: Double((val >> 8) & 0xFF) / 255.0,
            blue: Double(val & 0xFF) / 255.0
        )
    }
}

// MARK: - PinnedSite

public struct PinnedSite: Codable, Identifiable, Hashable, Sendable {
    /// Stable pinned-site identifier.
    public let id: String
    /// User-visible pinned-site name.
    public var name: String
    /// Canonical URL string loaded for this site.
    public var urlString: String
    /// SF Symbol fallback icon name.
    public var iconName: String          // SF Symbol name
    /// Whether favicon should be preferred over SF Symbol.
    public var useFavicon: Bool          // true = show cached favicon instead of SF Symbol
    /// Optional six-digit hex color string for badges.
    public var colorHex: String?         // optional color dot (#FF5733)
    /// Optional parent group identifier.
    public var groupID: String?          // ID of parent PinnedSiteGroup
    /// Optional auto-refresh interval in seconds.
    public var autoRefreshSeconds: Int?  // nil = no auto-refresh
    /// Display order index among pinned sites.
    public var sortOrder: Int

    /// Creates a pinned-site value.
    ///
    /// - Parameters:
    ///   - id: Stable identifier. Defaults to a new UUID string.
    ///   - name: User-visible site name.
    ///   - urlString: Absolute URL string to load.
    ///   - iconName: SF Symbol fallback icon name.
    ///   - useFavicon: Whether to display cached favicon when available.
    ///   - colorHex: Optional six-digit hex color.
    ///   - groupID: Optional parent group identifier.
    ///   - autoRefreshSeconds: Optional periodic reload interval.
    ///   - sortOrder: Display ordering index.
    public init(
        id: String = UUID().uuidString,
        name: String,
        urlString: String,
        iconName: String = "globe",
        useFavicon: Bool = true,
        colorHex: String? = nil,
        groupID: String? = nil,
        autoRefreshSeconds: Int? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.iconName = iconName
        self.useFavicon = useFavicon
        self.colorHex = colorHex
        self.groupID = groupID
        self.autoRefreshSeconds = autoRefreshSeconds
        self.sortOrder = sortOrder
    }

    // Graceful decoder for forward compatibility
    /// Decodes pinned-site data while applying defaults for missing keys.
    ///
    /// - Parameter decoder: Decoder containing persisted site data.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        urlString = try c.decode(String.self, forKey: .urlString)
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName) ?? "globe"
        useFavicon = try c.decodeIfPresent(Bool.self, forKey: .useFavicon) ?? true
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        groupID = try c.decodeIfPresent(String.self, forKey: .groupID)
        autoRefreshSeconds = try c.decodeIfPresent(Int.self, forKey: .autoRefreshSeconds)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    /// Parsed URL built from `urlString`.
    public var url: URL? { URL(string: urlString) }

    /// Whether the site points to common localhost hosts.
    public var isLocalhost: Bool {
        guard let url else { return false }
        let host = url.host() ?? ""
        return host == "localhost" || host == "127.0.0.1" || host == "0.0.0.0"
    }

    /// Decoded RGB tuple from `colorHex`, when valid.
    public var color: (red: Double, green: Double, blue: Double)? {
        guard let hex = colorHex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")) else { return nil }
        guard hex.count == 6, let val = UInt64(hex, radix: 16) else { return nil }
        return (
            red: Double((val >> 16) & 0xFF) / 255.0,
            green: Double((val >> 8) & 0xFF) / 255.0,
            blue: Double(val & 0xFF) / 255.0
        )
    }
}

// MARK: - PinnedSiteStore data envelope

public struct PinnedSiteStoreData: Codable, Sendable {
    /// Persisted pinned sites.
    public var sites: [PinnedSite]
    /// Persisted pinned-site groups.
    public var groups: [PinnedSiteGroup]

    /// Creates the serialized pinned-site store payload.
    ///
    /// - Parameters:
    ///   - sites: Persisted site values.
    ///   - groups: Persisted group values.
    public init(sites: [PinnedSite] = [], groups: [PinnedSiteGroup] = []) {
        self.sites = sites
        self.groups = groups
    }
}
