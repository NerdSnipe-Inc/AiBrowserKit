#if canImport(AppKit)
import Foundation

/// Manages multi-tab browser state.
@MainActor
@Observable
public final class BrowserViewModel {
    public var tabs: [BrowserTab] = []
    public var selectedTabID: String?
    private let consoleStore: ConsoleLogStore?

    public var selectedTab: BrowserTab? {
        guard let id = selectedTabID else { return tabs.first }
        return tabs.first { $0.id == id }
    }

    public init(consoleStore: ConsoleLogStore? = nil) {
        self.consoleStore = consoleStore
        let initial = BrowserTab(consoleStore: consoleStore)
        tabs = [initial]
        selectedTabID = initial.id
    }

    public func newTab(url: URL? = nil) {
        let tab = BrowserTab(url: url, consoleStore: consoleStore)
        tabs.append(tab)
        selectedTabID = tab.id
    }

    public func closeTab(_ id: String) {
        guard tabs.count > 1 else { return }
        let wasSelected = selectedTabID == id
        tabs.removeAll { $0.id == id }
        if wasSelected {
            selectedTabID = tabs.last?.id
        }
    }

    public func selectTab(_ id: String) {
        selectedTabID = id
    }
}
#endif
