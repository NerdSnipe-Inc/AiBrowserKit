import Foundation
import Testing
@testable import AiBrowserKit

@Suite("BookmarkService persistence", .serialized)
@MainActor
struct BookmarkServiceTests {

    private func makeService() -> (BookmarkService, URL) {
        let dir = TestSupport.makeStorageDirectory()
        return (BookmarkService(storageDirectory: dir), dir)
    }

    @Test("Add bookmark writes JSONL and reloads")
    func addAndReload() throws {
        let (service, dir) = makeService()
        defer { TestSupport.removeStorageDirectory(dir) }

        service.add(title: "Example", urlString: "https://example.com")
        #expect(service.bookmarks.count == 1)

        let reloaded = BookmarkService(storageDirectory: dir)
        #expect(reloaded.bookmarks.count == 1)
        #expect(reloaded.bookmarks[0].title == "Example")
        #expect(reloaded.bookmarks[0].urlString == "https://example.com")
    }

    @Test("Duplicate URL is not added twice")
    func deduplicatesURL() {
        let (service, dir) = makeService()
        defer { TestSupport.removeStorageDirectory(dir) }

        service.add(title: "One", urlString: "https://dup.test")
        service.add(title: "Two", urlString: "https://dup.test")
        #expect(service.bookmarks.count == 1)
    }

    @Test("Toggle bookmark adds then removes")
    func toggleBookmark() {
        let (service, dir) = makeService()
        defer { TestSupport.removeStorageDirectory(dir) }

        let url = URL(string: "https://toggle.test")!
        service.toggleBookmark(title: "Toggle", url: url)
        #expect(service.isBookmarked(url: url))

        service.toggleBookmark(title: "Toggle", url: url)
        #expect(!service.isBookmarked(url: url))
    }

    @Test("Folder CRUD and bookmark move")
    func foldersAndMove() {
        let (service, dir) = makeService()
        defer { TestSupport.removeStorageDirectory(dir) }

        service.addFolder(name: "Work")
        let folderID = service.folders[0].id
        service.add(title: "Task", urlString: "https://task.test", folderID: folderID)
        #expect(service.bookmarks(inFolder: folderID).count == 1)

        service.renameFolder(id: folderID, name: "Projects")
        #expect(service.folders[0].name == "Projects")

        service.removeFolder(id: folderID)
        #expect(service.bookmarks[0].folderID == nil)
        #expect(service.folders.isEmpty)
    }

    @Test("Remove bookmark deletes from disk")
    func removeBookmark() {
        let (service, dir) = makeService()
        defer { TestSupport.removeStorageDirectory(dir) }

        service.add(title: "Gone", urlString: "https://gone.test")
        let id = service.bookmarks[0].id
        service.remove(id: id)

        let reloaded = BookmarkService(storageDirectory: dir)
        #expect(reloaded.bookmarks.isEmpty)
    }
}
