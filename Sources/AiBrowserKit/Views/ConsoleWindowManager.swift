#if canImport(AppKit)
import SwiftUI
import AppKit

/// Manages a single detached console log panel window.
@MainActor
public final class ConsoleWindowManager {
    /// Shared singleton instance for console panel lifecycle.
    public static let shared = ConsoleWindowManager()
    private var windowController: NSWindowController?

    private init() {}

    /// Whether the detached console window is currently visible.
    public var isOpen: Bool { windowController?.window?.isVisible == true }

    /// Toggles the detached console window.
    ///
    /// - Parameter store: Console store displayed in the panel.
    public func toggle(store: ConsoleLogStore) {
        if isOpen {
            windowController?.close()
            windowController = nil
        } else {
            open(store: store)
        }
    }

    private func open(store: ConsoleLogStore) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Console"
        panel.minSize = NSSize(width: 400, height: 200)
        panel.center()
        panel.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: ConsoleLogView(store: store))
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        let wc = NSWindowController(window: panel)
        wc.showWindow(nil)
        windowController = wc
    }
}
#endif
