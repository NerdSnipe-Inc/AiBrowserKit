import Foundation
#if canImport(WebKit)
import WebKit
#endif

enum IntegrationTestGate {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] != nil
    }
}

enum TestSupport {
    static func makeStorageDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AiBrowserKitTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func removeStorageDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    #if canImport(WebKit)
    @MainActor
    static func waitUntil(
        timeout: TimeInterval = 15,
        pollInterval: UInt64 = 100_000_000,
        condition: () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: pollInterval)
        }
        return false
    }
    #endif
}
