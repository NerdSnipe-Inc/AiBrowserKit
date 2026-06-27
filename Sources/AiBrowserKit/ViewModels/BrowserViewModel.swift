#if canImport(AppKit)
import Foundation

/// Manages multi-tab browser state.
@MainActor
@Observable
public final class BrowserViewModel {
    /// Ordered list of open browser tabs.
    public var tabs: [BrowserTab] = []
    /// Identifier of the currently selected tab.
    public var selectedTabID: String?
    private let consoleStore: ConsoleLogStore?

    /// Currently selected tab, or the first tab when no explicit selection exists.
    public var selectedTab: BrowserTab? {
        guard let id = selectedTabID else { return tabs.first }
        return tabs.first { $0.id == id }
    }

    /// Creates a tab view model with one initial blank tab.
    ///
    /// - Parameter consoleStore: Optional console destination for JavaScript logs.
    public init(consoleStore: ConsoleLogStore? = nil) {
        self.consoleStore = consoleStore
        let initial = BrowserTab(consoleStore: consoleStore)
        tabs = [initial]
        selectedTabID = initial.id
    }

    /// Opens a new tab and makes it the current selection.
    ///
    /// - Parameter url: Optional initial URL to load immediately.
    public func newTab(url: URL? = nil) {
        let tab = BrowserTab(url: url, consoleStore: consoleStore)
        tabs.append(tab)
        selectedTabID = tab.id
    }

    /// Closes a tab by identifier while keeping at least one tab open.
    ///
    /// - Parameter id: Identifier of the tab to close.
    public func closeTab(_ id: String) {
        guard tabs.count > 1 else { return }
        let wasSelected = selectedTabID == id
        tabs.removeAll { $0.id == id }
        if wasSelected {
            selectedTabID = tabs.last?.id
        }
    }

    /// Marks a tab as selected.
    ///
    /// - Parameter id: Identifier of the tab to select.
    public func selectTab(_ id: String) {
        selectedTabID = id
    }
}
#endif
