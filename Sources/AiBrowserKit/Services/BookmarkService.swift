import Foundation

/// Reads and writes bookmarks (JSONL) and folders (JSON) to a configurable storage directory.
/// Defaults to ~/Library/Application Support/AiBrowserKit/.
/// Pass a custom directory to share data with other apps or use a legacy path.
@MainActor
@Observable
public final class BookmarkService {
    public var bookmarks: [BrowserBookmark] = []
    public var folders:   [BookmarkFolder]  = []

    private let bookmarksURL: URL
    private let foldersURL: URL

    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    public init(storageDirectory: URL? = nil) {
        let dir: URL
        if let storageDirectory {
            dir = storageDirectory
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            dir = appSupport.appendingPathComponent("AiBrowserKit")
        }
        bookmarksURL = dir.appendingPathComponent("bookmarks.jsonl")
        foldersURL   = dir.appendingPathComponent("bookmark_folders.json")
        load()
    }

    // MARK: - Load

    public func load() {
        loadBookmarks()
        loadFolders()
    }

    private func loadBookmarks() {
        guard FileManager.default.fileExists(atPath: bookmarksURL.path()) else { bookmarks = []; return }
        do {
            let content = try String(contentsOf: bookmarksURL, encoding: .utf8)
            bookmarks = content
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .compactMap { line -> BrowserBookmark? in
                    guard let data = line.data(using: .utf8) else { return nil }
                    return try? decoder.decode(BrowserBookmark.self, from: data)
                }
        } catch { bookmarks = [] }
    }

    private func loadFolders() {
        guard FileManager.default.fileExists(atPath: foldersURL.path()) else { folders = []; return }
        do {
            let data = try Data(contentsOf: foldersURL)
            folders = try decoder.decode([BookmarkFolder].self, from: data)
        } catch { folders = [] }
    }

    // MARK: - Bookmark mutations

    public func add(title: String, urlString: String, folderID: String? = nil) {
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bookmarks.contains(where: { $0.urlString == normalized }) else { return }
        bookmarks.append(BrowserBookmark(title: title, urlString: normalized, folderID: folderID))
        saveBookmarks()
    }

    public func remove(id: String) {
        bookmarks.removeAll { $0.id == id }
        saveBookmarks()
    }

    public func isBookmarked(url: URL?) -> Bool {
        guard let url else { return false }
        return bookmarks.contains { $0.urlString == url.absoluteString }
    }

    public func toggleBookmark(title: String, url: URL?) {
        guard let url else { return }
        let str = url.absoluteString
        if let existing = bookmarks.first(where: { $0.urlString == str }) {
            remove(id: existing.id)
        } else {
            add(title: title, urlString: str)
        }
    }

    public func moveBookmark(id: String, toFolderID folderID: String?) {
        guard let idx = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        bookmarks[idx].folderID = folderID
        saveBookmarks()
    }

    // MARK: - Folder mutations

    public func addFolder(name: String) {
        let folder = BookmarkFolder(name: name, sortOrder: folders.count)
        folders.append(folder)
        saveFolders()
    }

    public func renameFolder(id: String, name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = name
        saveFolders()
    }

    public func removeFolder(id: String) {
        // Move all bookmarks in this folder to Unfiled
        for i in bookmarks.indices where bookmarks[i].folderID == id {
            bookmarks[i].folderID = nil
        }
        folders.removeAll { $0.id == id }
        saveBookmarks()
        saveFolders()
    }

    // MARK: - Queries

    public func bookmarks(inFolder folderID: String?) -> [BrowserBookmark] {
        bookmarks.filter { $0.folderID == folderID }
    }

    public var sortedFolders: [BookmarkFolder] {
        folders.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Persistence

    private func saveBookmarks() {
        let dir = bookmarksURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let lines = bookmarks.compactMap { b -> String? in
            guard let data = try? encoder.encode(b) else { return nil }
            // Encode as compact single-line JSON for JSONL
            let compact = JSONEncoder()
            guard let d = try? compact.encode(b) else { return nil }
            return String(data: d, encoding: .utf8)
        }
        let content = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        try? content.write(to: bookmarksURL, atomically: true, encoding: .utf8)
    }

    private func saveFolders() {
        let dir = foldersURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? encoder.encode(folders) {
            try? data.write(to: foldersURL)
        }
    }
}
