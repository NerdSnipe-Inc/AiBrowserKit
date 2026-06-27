import Foundation

public enum ConsoleLevel: String, CaseIterable, Sendable {
    case log, info, warn, error, debug

    var label: String { rawValue.capitalized }
}

public struct ConsoleEntry: Identifiable, Sendable {
    public let id: UUID
    public let level: ConsoleLevel
    public let message: String
    public let source: String?
    public let timestamp: Date

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
    public var entries: [ConsoleEntry] = []
    private let maxEntries = 500

    public init() {}

    public func append(_ entry: ConsoleEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public func clear() { entries.removeAll() }
}
