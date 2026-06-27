import Foundation

// MARK: - BookmarkFolder

public struct BookmarkFolder: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var sortOrder: Int

    public init(id: String = UUID().uuidString, name: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}

// MARK: - BrowserBookmark

/// A single browser bookmark, stored as one JSON line in bookmarks.jsonl.
public struct BrowserBookmark: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var urlString: String
    public var createdAt: String // ISO 8601
    public var folderID: String? // nil = unfiled

    public init(
        id: String = UUID().uuidString,
        title: String,
        urlString: String,
        folderID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.folderID = folderID
    }

    // Graceful decode — folderID is absent in older saved data
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        title     = try c.decode(String.self, forKey: .title)
        urlString = try c.decode(String.self, forKey: .urlString)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
                    ?? ISO8601DateFormatter().string(from: Date())
        folderID  = try c.decodeIfPresent(String.self, forKey: .folderID)
    }

    public var url: URL? { URL(string: urlString) }

    public var displayHost: String {
        url?.host() ?? urlString
    }
}
