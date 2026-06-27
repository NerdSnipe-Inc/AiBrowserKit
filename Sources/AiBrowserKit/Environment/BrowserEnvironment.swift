#if canImport(AppKit)
import Foundation
import AppKit

// MARK: - AiBrowserClipboardContent

/// Content delivered to the host app's clipboard handler from AiBrowserKit.
public struct AiBrowserClipboardContent: Sendable {
    public enum Kind: @unchecked Sendable {
        case text(String)
        case image(NSImage)
    }
    public let kind: Kind
    public let sourceURL: String?

    public init(kind: Kind, sourceURL: String?) {
        self.kind = kind
        self.sourceURL = sourceURL
    }
}

// MARK: - BrowserEnvironment

/// Shared browser environment injected at app root.
/// Holds all browser-related state managers.
@MainActor
@Observable
public final class BrowserEnvironment {
    public let browserVM: BrowserViewModel
    public let bookmarks: BookmarkService
    public let favicons: FaviconService
    public let pinnedSites: PinnedSiteStore
    public let webViewCache: PinnedSiteWebViewCache
    public let consoleStore: ConsoleLogStore

    /// Optional callback wired up by the host app to receive content that
    /// should be added to the app-wide clipboard store.
    public var onAddToClipboard: ((AiBrowserClipboardContent) -> Void)? = nil

    public init(storageDirectory: URL? = nil) {
        let dir = AiBrowserStorage.directory(custom: storageDirectory)
        let console = ConsoleLogStore()
        self.consoleStore = console
        self.browserVM   = BrowserViewModel(consoleStore: console)
        self.bookmarks   = BookmarkService(storageDirectory: dir)
        self.favicons    = FaviconService(storageDirectory: dir)
        self.pinnedSites = PinnedSiteStore(storageDirectory: dir)
        self.webViewCache = PinnedSiteWebViewCache()
    }
}
#endif
