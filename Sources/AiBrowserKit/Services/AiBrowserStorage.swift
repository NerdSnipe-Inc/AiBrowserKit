import Foundation

/// Default on-disk layout for AiBrowserKit data under Application Support.
enum AiBrowserStorage {

    static func directory(custom: URL? = nil) -> URL {
        if let custom { return custom }
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("AiBrowserKit", isDirectory: true)
    }

    /// Copies pinned sites from the pre-1.0 default location when the new file is absent.
    static func migratePinnedSitesIfNeeded(to destination: URL) {
        guard !FileManager.default.fileExists(atPath: destination.path()) else { return }
        let legacy = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".eggspert/data/pinned_sites.json")
        guard FileManager.default.fileExists(atPath: legacy.path()) else { return }
        let parent = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try? FileManager.default.copyItem(at: legacy, to: destination)
    }

    /// Copies favicon PNGs from the pre-1.0 cache when the new directory is empty.
    static func migrateFaviconCacheIfNeeded(to destination: URL) {
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: destination.path()), !contents.isEmpty {
            return
        }
        let legacy = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".eggspert/cache/favicons", isDirectory: true)
        guard fm.fileExists(atPath: legacy.path()),
              let files = try? fm.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil),
              !files.isEmpty else { return }
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for file in files where file.pathExtension == "png" {
            let target = destination.appendingPathComponent(file.lastPathComponent)
            if !fm.fileExists(atPath: target.path()) {
                try? fm.copyItem(at: file, to: target)
            }
        }
    }
}
