import Foundation

// MARK: - PinnedSiteGroup

public struct PinnedSiteGroup: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var iconName: String
    public var colorHex: String?
    public var sortOrder: Int

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
    public let id: String
    public var name: String
    public var urlString: String
    public var iconName: String          // SF Symbol name
    public var useFavicon: Bool          // true = show cached favicon instead of SF Symbol
    public var colorHex: String?         // optional color dot (#FF5733)
    public var groupID: String?          // ID of parent PinnedSiteGroup
    public var autoRefreshSeconds: Int?  // nil = no auto-refresh
    public var sortOrder: Int

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

    public var url: URL? { URL(string: urlString) }

    public var isLocalhost: Bool {
        guard let url else { return false }
        let host = url.host() ?? ""
        return host == "localhost" || host == "127.0.0.1" || host == "0.0.0.0"
    }

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
    public var sites: [PinnedSite]
    public var groups: [PinnedSiteGroup]

    public init(sites: [PinnedSite] = [], groups: [PinnedSiteGroup] = []) {
        self.sites = sites
        self.groups = groups
    }
}
