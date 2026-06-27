import Foundation
import Testing
@testable import AiBrowserKit

#if canImport(AppKit)
import AppKit

@Suite("FaviconService — disk cache")
@MainActor
struct FaviconServiceTests {

    private func writeMinimalPNG(to url: URL) throws {
        // 1×1 opaque red PNG (67 bytes)
        let png: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
            0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
            0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
            0x44, 0xAE, 0x42, 0x60, 0x82,
        ]
        try Data(png).write(to: url)
    }

    @Test("cachedImage loads PNG written to favicons directory")
    func cachedImageFromDisk() throws {
        let dir = TestSupport.makeStorageDirectory()
        defer { TestSupport.removeStorageDirectory(dir) }

        let faviconDir = dir.appendingPathComponent("favicons", isDirectory: true)
        try FileManager.default.createDirectory(at: faviconDir, withIntermediateDirectories: true)
        try writeMinimalPNG(to: faviconDir.appendingPathComponent("site-a.png"))

        let service = FaviconService(storageDirectory: dir)
        #expect(service.cachedImage(for: "site-a") != nil)
    }

    @Test("Evict removes memory and disk cache entry")
    func evictRemovesEntry() throws {
        let dir = TestSupport.makeStorageDirectory()
        defer { TestSupport.removeStorageDirectory(dir) }

        let faviconDir = dir.appendingPathComponent("favicons", isDirectory: true)
        try FileManager.default.createDirectory(at: faviconDir, withIntermediateDirectories: true)
        let path = faviconDir.appendingPathComponent("site-b.png")
        try writeMinimalPNG(to: path)

        let service = FaviconService(storageDirectory: dir)
        #expect(service.cachedImage(for: "site-b") != nil)

        service.evict(itemID: "site-b")
        #expect(service.cachedImage(for: "site-b") == nil)
        #expect(!FileManager.default.fileExists(atPath: path.path))
    }
}
#endif
