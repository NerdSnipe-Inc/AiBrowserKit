#if canImport(AppKit)
import AppKit
import Foundation

/// Fetches and caches site favicons to disk under the configured storage directory.
@MainActor
public final class FaviconService {
    private let cacheDir: URL
    private var memoryCache: [String: NSImage] = [:]

    public init(storageDirectory: URL? = nil) {
        let dir = AiBrowserStorage.directory(custom: storageDirectory)
        self.cacheDir = dir.appendingPathComponent("favicons", isDirectory: true)
        if storageDirectory == nil {
            AiBrowserStorage.migrateFaviconCacheIfNeeded(to: cacheDir)
        }
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    public func cachedImage(for itemID: String) -> NSImage? {
        if let mem = memoryCache[itemID] { return mem }
        let path = cacheDir.appendingPathComponent("\(itemID).png")
        guard FileManager.default.fileExists(atPath: path.path()),
              let image = NSImage(contentsOf: path) else { return nil }
        memoryCache[itemID] = image
        return image
    }

    public func fetchFavicon(for urlString: String, itemID: String) async -> NSImage? {
        guard let baseURL = URL(string: urlString),
              let host = baseURL.host() else { return nil }

        if let image = await downloadImage(from: "https://\(host)/favicon.ico") {
            save(image, itemID: itemID)
            return image
        }

        let googleURL = "https://www.google.com/s2/favicons?domain=\(host)&sz=64"
        if let image = await downloadImage(from: googleURL) {
            save(image, itemID: itemID)
            return image
        }

        if baseURL.scheme == "https" {
            if let image = await downloadImage(from: "http://\(host)/favicon.ico") {
                save(image, itemID: itemID)
                return image
            }
        }

        return nil
    }

    public func evict(itemID: String) {
        memoryCache.removeValue(forKey: itemID)
        let path = cacheDir.appendingPathComponent("\(itemID).png")
        try? FileManager.default.removeItem(at: path)
    }

    // MARK: - Internal

    private func downloadImage(from urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            guard data.count > 50, let image = NSImage(data: data) else { return nil }

            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                // Google S2 and some CDNs return 404 with a PNG/ICO fallback body.
                let isPNG = data.starts(with: [0x89, 0x50, 0x4E, 0x47])
                let isICO = data.starts(with: [0x00, 0x00, 0x01, 0x00])
                guard isPNG || isICO else { return nil }
            }

            return image
        } catch {
            return nil
        }
    }

    private func save(_ image: NSImage, itemID: String) {
        memoryCache[itemID] = image
        let path = cacheDir.appendingPathComponent("\(itemID).png")
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: path)
    }
}
#endif
