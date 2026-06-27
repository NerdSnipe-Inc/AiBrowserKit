import SwiftUI

public struct ConsoleLogView: View {
    let store: ConsoleLogStore
    @State private var filter: ConsoleLevel? = nil

    public init(store: ConsoleLogStore) {
        self.store = store
    }

    private var filtered: [ConsoleEntry] {
        guard let f = filter else { return store.entries }
        return store.entries.filter { $0.level == f }
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.15)
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "terminal",
                    description: Text(
                        filter == nil
                            ? "Console output will appear here."
                            : "No \(filter!.label) messages."
                    )
                )
            } else {
                ScrollViewReader { proxy in
                    List(filtered) { entry in
                        ConsoleEntryRow(entry: entry)
                            .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                            .listRowSeparator(.hidden)
                            .id(entry.id)
                    }
                    .listStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: filtered.count) { _, _ in
                        if let last = filtered.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            filterChip(nil, label: "All")
            ForEach(ConsoleLevel.allCases, id: \.rawValue) { level in
                filterChip(level, label: level.label)
            }

            Spacer()

            Text("\(filtered.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button("Clear") { store.clear() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func filterChip(_ level: ConsoleLevel?, label: String) -> some View {
        let active = filter == level
        return Button { filter = level } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(active ? Color.accentColor.opacity(0.15) : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            active ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Entry Row

private struct ConsoleEntryRow: View {
    let entry: ConsoleEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(String(entry.level.label.prefix(1)))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(levelColor)
                .frame(width: 12, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.message)
                    .foregroundStyle(levelColor.opacity(0.9))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                if let source = entry.source, !source.isEmpty {
                    Text(source)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 4)

            Text(entry.timestamp, style: .time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 2)
    }

    private var levelColor: Color {
        switch entry.level {
        case .log:   .primary
        case .info:  .blue
        case .warn:  .orange
        case .error: .red
        case .debug: .secondary
        }
    }
}
