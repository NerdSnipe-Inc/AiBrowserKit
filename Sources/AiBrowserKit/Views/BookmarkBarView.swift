import SwiftUI

/// Horizontal bookmark bar showing quick-access pills for unfiled bookmarks and folder menus.
/// Place below the address bar; hidden automatically when no bookmarks exist.
public struct BookmarkBarView: View {
    let service: BookmarkService
    let onNavigate: (URL) -> Void

    public init(service: BookmarkService, onNavigate: @escaping (URL) -> Void) {
        self.service = service
        self.onNavigate = onNavigate
    }

    private var unfiledBookmarks: [BrowserBookmark] { service.bookmarks(inFolder: nil) }
    private var folders: [BookmarkFolder] { service.sortedFolders }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(unfiledBookmarks) { bookmark in
                    BookmarkBarItem(bookmark: bookmark, onNavigate: onNavigate)
                }

                if !unfiledBookmarks.isEmpty && !folders.isEmpty {
                    Divider()
                        .frame(height: 14)
                        .padding(.horizontal, 3)
                }

                ForEach(folders) { folder in
                    BookmarkBarFolder(folder: folder, service: service, onNavigate: onNavigate)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
        }
        .frame(height: 28)
    }
}

// MARK: - Bookmark pill

private struct BookmarkBarItem: View {
    let bookmark: BrowserBookmark
    let onNavigate: (URL) -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            if let url = bookmark.url { onNavigate(url) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.yellow.opacity(0.9))
                Text(bookmark.shortBarTitle)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(isHovered ? Color.primary : Color.secondary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.secondary.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(bookmark.urlString)
        #if os(macOS) || os(visionOS)
        .onHover { isHovered = $0 }
        #endif
    }
}

// MARK: - Folder menu

private struct BookmarkBarFolder: View {
    let folder: BookmarkFolder
    let service: BookmarkService
    let onNavigate: (URL) -> Void
    @State private var isHovered = false

    private var items: [BrowserBookmark] { service.bookmarks(inFolder: folder.id) }

    var body: some View {
        Menu {
            if items.isEmpty {
                Text("Empty folder")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { bookmark in
                    Button {
                        if let url = bookmark.url { onNavigate(url) }
                    } label: {
                        Label(bookmark.title, systemImage: "star.fill")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
                Text(folder.name)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.secondary.opacity(0.12) : Color.clear)
            )
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        #endif
        .fixedSize()
        #if os(macOS) || os(visionOS)
        .onHover { isHovered = $0 }
        #endif
    }
}

// MARK: - BrowserBookmark extension

extension BrowserBookmark {
    var shortBarTitle: String {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard t.count > 22 else { return t }
        return String(t.prefix(20)) + "…"
    }
}
