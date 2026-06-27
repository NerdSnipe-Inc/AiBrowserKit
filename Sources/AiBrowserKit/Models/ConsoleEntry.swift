import Foundation

/// JavaScript console severity levels captured from web pages.
public enum ConsoleLevel: String, CaseIterable, Sendable {
    case log, info, warn, error, debug

    var label: String { rawValue.capitalized }
}

/// A single console log event emitted by a web page.
public struct ConsoleEntry: Identifiable, Sendable {
    /// Stable entry identifier.
    public let id: UUID
    /// Severity level of the log event.
    public let level: ConsoleLevel
    /// Human-readable log text payload.
    public let message: String
    /// Optional source URL for the event.
    public let source: String?
    /// Capture timestamp.
    public let timestamp: Date

    /// Creates a console entry value.
    ///
    /// - Parameters:
    ///   - level: Severity of the log event.
    ///   - message: Human-readable log text.
    ///   - source: Optional source URL.
    ///   - timestamp: Capture time, defaulting to `Date.now`.
    public init(level: ConsoleLevel, message: String, source: String?, timestamp: Date = .now) {
        self.id = UUID()
        self.level = level
        self.message = message
        self.source = source
        self.timestamp = timestamp
    }
}

@MainActor
@Observable
public final class ConsoleLogStore {
    /// In-memory ring buffer of console entries.
    public var entries: [ConsoleEntry] = []
    private let maxEntries = 500

    /// Creates an empty console log store.
    public init() {}

    /// Appends a console event and trims history to the configured maximum.
    ///
    /// - Parameter entry: Entry to append.
    public func append(_ entry: ConsoleEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    /// Removes all stored console entries.
    public func clear() { entries.removeAll() }
}
