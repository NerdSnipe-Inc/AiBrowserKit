import Foundation

// MARK: - BookmarkFolder

public struct BookmarkFolder: Codable, Identifiable, Hashable, Sendable {
    /// Stable folder identifier.
    public let id: String
    /// User-visible folder name.
    public var name: String
    /// Display order used for folder sorting.
    public var sortOrder: Int

    /// Creates a bookmark folder.
    ///
    /// - Parameters:
    ///   - id: Stable identifier. Defaults to a new UUID string.
    ///   - name: User-visible folder name.
    ///   - sortOrder: Folder ordering index.
    public init(id: String = UUID().uuidString, name: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}

// MARK: - BrowserBookmark

/// A single browser bookmark, stored as one JSON line in bookmarks.jsonl.
public struct BrowserBookmark: Codable, Identifiable, Hashable, Sendable {
    /// Stable bookmark identifier.
    public let id: String
    /// User-visible bookmark title.
    public var title: String
    /// Canonical absolute URL string.
    public var urlString: String
    /// ISO 8601 creation timestamp.
    public var createdAt: String // ISO 8601
    /// Optional folder membership identifier (`nil` means Unfiled).
    public var folderID: String? // nil = unfiled

    /// Creates a bookmark value.
    ///
    /// - Parameters:
    ///   - id: Stable identifier. Defaults to a new UUID string.
    ///   - title: User-visible bookmark title.
    ///   - urlString: Absolute URL string to persist.
    ///   - folderID: Optional folder assignment.
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
    /// Decodes bookmarks while tolerating older payloads without `folderID`.
    ///
    /// - Parameter decoder: Decoder containing bookmark fields.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        title     = try c.decode(String.self, forKey: .title)
        urlString = try c.decode(String.self, forKey: .urlString)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
                    ?? ISO8601DateFormatter().string(from: Date())
        folderID  = try c.decodeIfPresent(String.self, forKey: .folderID)
    }

    /// Parsed URL built from `urlString`.
    public var url: URL? { URL(string: urlString) }

    /// Host text used in compact bookmark UI rows.
    public var displayHost: String {
        url?.host() ?? urlString
    }
}
