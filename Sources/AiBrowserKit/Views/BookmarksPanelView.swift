#if canImport(AppKit)
import SwiftUI

private let expandedDefaultsKey = "aibrowserkit.bookmarks.expandedFolderIDs"

/// Right-side slide-out panel showing bookmarks organised into collapsible folders.
/// Drag a bookmark row onto any folder header to move it. Collapse state persists via UserDefaults.
public struct BookmarksPanelView: View {
    @Environment(BrowserEnvironment.self) private var browserEnv
    let onNavigate: (URL) -> Void

    // Persisted collapse state — stored as comma-separated folder IDs
    @State private var expandedIDs: Set<String> = {
        let stored = UserDefaults.standard.stringArray(forKey: expandedDefaultsKey) ?? []
        return Set(stored)
    }()

    // New-folder UI
    @State private var showNewFolderField = false
    @State private var newFolderName = ""
    @State private var glowPulse = false          // drives the repeating glow animation
    @FocusState private var newFolderFocused: Bool

    // Rename
    @State private var renamingFolderID: String?
    @State private var renameText = ""

    // Drag state — tracks which bookmark is being dragged
    @State private var draggingID: String?
    // Which drop target is currently highlighted (folderID or "__unfiled__")
    @State private var highlightedTarget: String?

    /// Creates the bookmarks side panel.
    ///
    /// - Parameter onNavigate: Callback invoked when a bookmark is selected.
    public init(onNavigate: @escaping (URL) -> Void) {
        self.onNavigate = onNavigate
    }

    private var service: BookmarkService { browserEnv.bookmarks }

    /// Renders folders, bookmark rows, and folder management controls.
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader

            Divider().opacity(0.15)

            if service.bookmarks.isEmpty && service.folders.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Unfiled section
                        folderSection(
                            id: "__unfiled__",
                            name: "Unfiled",
                            icon: "tray",
                            bookmarks: service.bookmarks(inFolder: nil)
                        )

                        // Named folders
                        ForEach(service.sortedFolders) { folder in
                            folderSection(
                                id: folder.id,
                                name: folder.name,
                                icon: "folder.fill",
                                bookmarks: service.bookmarks(inFolder: folder.id),
                                folder: folder
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // New folder inline field
            if showNewFolderField {
                Divider().opacity(0.1)
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor.opacity(glowPulse ? 1.0 : 0.5))
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: glowPulse)

                    TextField("Folder name", text: $newFolderName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($newFolderFocused)
                        .onSubmit { commitNewFolder() }
                        .onChange(of: newFolderName) { _, _ in
                            // user is typing — stop pulsing, settle to solid
                            if glowPulse { glowPulse = false }
                        }

                    Button { commitNewFolder() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button { cancelNewFolder() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(glowPulse ? 0.08 : 0.04))
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: glowPulse)
                        .padding(.horizontal, 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            Color.accentColor.opacity(glowPulse ? 0.55 : 0.2),
                            lineWidth: 1.5
                        )
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: glowPulse)
                        .padding(.horizontal, 6)
                )
                .shadow(
                    color: Color.accentColor.opacity(glowPulse ? 0.35 : 0.0),
                    radius: glowPulse ? 10 : 2
                )
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: glowPulse)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    // Small delay so the view is fully laid out before animation starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        glowPulse = true
                    }
                }
                .onDisappear { glowPulse = false }
            }
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
    }

    // MARK: - Panel header

    private var panelHeader: some View {
        HStack {
            Image(systemName: "book.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
            Text("Bookmarks")
                .font(.headline)
            Spacer()
            Text("\(service.bookmarks.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button {
                withAnimation(.snappy(duration: 0.15)) {
                    showNewFolderField.toggle()
                    if showNewFolderField {
                        newFolderName = ""
                        newFolderFocused = true
                    }
                }
            } label: {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 13))
                    .foregroundStyle(showNewFolderField ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("New folder")
        }
        .padding(12)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "star")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No bookmarks yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Click the star in the URL bar to save pages here")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(12)
    }

    // MARK: - Folder section

    @ViewBuilder
    private func folderSection(
        id: String,
        name: String,
        icon: String,
        bookmarks: [BrowserBookmark],
        folder: BookmarkFolder? = nil
    ) -> some View {
        let isExpanded = expandedIDs.contains(id)
        let isHighlighted = highlightedTarget == id

        VStack(spacing: 0) {
            // Section header (also the drop target)
            folderHeader(
                id: id, name: name, icon: icon,
                count: bookmarks.count, isExpanded: isExpanded,
                isHighlighted: isHighlighted, folder: folder
            )

            // Rows
            if isExpanded {
                if bookmarks.isEmpty {
                    Text("No bookmarks")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 32)
                        .padding(.vertical, 6)
                } else {
                    ForEach(bookmarks) { bookmark in
                        bookmarkRow(bookmark)
                    }
                }
                Divider().opacity(0.08).padding(.leading, 12)
            }
        }
    }

    private func folderHeader(
        id: String,
        name: String,
        icon: String,
        count: Int,
        isExpanded: Bool,
        isHighlighted: Bool,
        folder: BookmarkFolder?
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Image(systemName: isExpanded ? icon + (icon == "folder.fill" ? "" : "") : icon)
                .font(.system(size: 11))
                .foregroundStyle(isHighlighted ? Color.accentColor : Color.secondary)

            // Rename inline or static label
            if renamingFolderID == id, let folder {
                TextField("", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .onSubmit { commitRename(folder) }
                    .onExitCommand { renamingFolderID = nil }
            } else {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(count)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHighlighted
                      ? Color.accentColor.opacity(0.12)
                      : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onTapGesture { toggleExpand(id) }
        .contextMenu { folderContextMenu(id: id, folder: folder) }
        // Drop target — accepts dragged bookmark IDs
        .dropDestination(for: String.self) { droppedIDs, _ in
            for bookmarkID in droppedIDs {
                let targetFolderID: String? = (id == "__unfiled__") ? nil : id
                service.moveBookmark(id: bookmarkID, toFolderID: targetFolderID)
                if !isExpanded { toggleExpand(id) } // auto-expand destination
            }
            draggingID = nil
            return true
        } isTargeted: { targeted in
            withAnimation(.snappy(duration: 0.1)) {
                highlightedTarget = targeted ? id : nil
            }
        }
    }

    // MARK: - Bookmark row

    private func bookmarkRow(_ bookmark: BrowserBookmark) -> some View {
        let isDragging = draggingID == bookmark.id

        return HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.yellow)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(bookmark.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(bookmark.displayHost)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.leading, 30)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .opacity(isDragging ? 0.4 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = bookmark.url { onNavigate(url) }
        }
        .draggable(bookmark.id) {
            // Drag preview
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.yellow)
                Text(bookmark.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .onAppear  { draggingID = bookmark.id }
            .onDisappear { draggingID = nil }
        }
        .contextMenu { bookmarkContextMenu(bookmark) }
    }

    // MARK: - Context menus

    @ViewBuilder
    private func bookmarkContextMenu(_ bookmark: BrowserBookmark) -> some View {
        if let url = bookmark.url {
            Button("Open in New Tab") {
                browserEnv.browserVM.newTab(url: url)
            }
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(bookmark.urlString, forType: .string)
            }
            Button("Open in Safari") { NSWorkspace.shared.open(url) }
        }

        Divider()

        // Move to folder submenu
        Menu("Move to") {
            Button("Unfiled") {
                service.moveBookmark(id: bookmark.id, toFolderID: nil)
            }
            .disabled(bookmark.folderID == nil)

            if !service.folders.isEmpty { Divider() }

            ForEach(service.sortedFolders) { folder in
                Button(folder.name) {
                    service.moveBookmark(id: bookmark.id, toFolderID: folder.id)
                }
                .disabled(bookmark.folderID == folder.id)
            }
        }

        Divider()
        Button("Delete", role: .destructive) {
            withAnimation(.snappy(duration: 0.15)) {
                service.remove(id: bookmark.id)
            }
        }
    }

    @ViewBuilder
    private func folderContextMenu(id: String, folder: BookmarkFolder?) -> some View {
        if let folder {
            Button("Rename") {
                renameText = folder.name
                renamingFolderID = folder.id
            }
            Divider()
            Button("Delete Folder", role: .destructive) {
                withAnimation(.snappy(duration: 0.15)) {
                    service.removeFolder(id: folder.id)
                    expandedIDs.remove(id)
                    persistExpanded()
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggleExpand(_ id: String) {
        withAnimation(.snappy(duration: 0.15)) {
            if expandedIDs.contains(id) {
                expandedIDs.remove(id)
            } else {
                expandedIDs.insert(id)
            }
        }
        persistExpanded()
    }

    private func persistExpanded() {
        UserDefaults.standard.set(Array(expandedIDs), forKey: expandedDefaultsKey)
    }

    private func commitNewFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancelNewFolder(); return }
        service.addFolder(name: name)
        cancelNewFolder()
    }

    private func cancelNewFolder() {
        glowPulse = false
        withAnimation(.snappy(duration: 0.15)) { showNewFolderField = false }
        newFolderName = ""
    }

    private func commitRename(_ folder: BookmarkFolder) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            service.renameFolder(id: folder.id, name: name)
        }
        renamingFolderID = nil
    }
}
#endif
