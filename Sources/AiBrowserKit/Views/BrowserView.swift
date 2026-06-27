#if canImport(AppKit)
import SwiftUI
import WebKit

/// Main multi-tab browser view.
public struct BrowserView: View {
    @Environment(BrowserEnvironment.self) private var browserEnv
    @State private var showAddToPinned = false
    @State private var showBookmarks = false
    @State private var selectionDestination: ScreenshotDestination?
    @State private var showConsole = false

    public init() {}

    private var viewModel: BrowserViewModel { browserEnv.browserVM }

    public var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            BrowserTabBar(
                tabs: viewModel.tabs,
                selectedTabID: viewModel.selectedTabID,
                onSelect: { viewModel.selectTab($0) },
                onClose: { viewModel.closeTab($0) },
                onNewTab: { viewModel.newTab() }
            )

            Divider().opacity(0.15)

            if let tab = viewModel.selectedTab {
                BrowserNavigationBar(
                    tab: tab,
                    onAddToPinned: { showAddToPinned = true },
                    onToggleBookmarks: {
                        withAnimation(.snappy(duration: 0.2)) { showBookmarks.toggle() }
                    },
                    onToggleConsole: {
                        ConsoleWindowManager.shared.toggle(store: browserEnv.consoleStore)
                        showConsole = ConsoleWindowManager.shared.isOpen
                    },
                    onStartSelection: { dest in selectionDestination = dest },
                    showingBookmarks: showBookmarks,
                    showingConsole: showConsole
                )

                // Progress bar
                if tab.state.isLoading {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * tab.state.estimatedProgress, height: 2)
                            .animation(.linear(duration: 0.2), value: tab.state.estimatedProgress)
                    }
                    .frame(height: 2)
                } else {
                    Divider().opacity(0.1)
                }

                HStack(spacing: 0) {
                    // Web content
                    ZStack {
                        if tab.isBlank {
                            BrowserNewTabView()
                        } else if let error = tab.state.error {
                            browserErrorView(error, tab: tab)
                        } else {
                            WebViewRepresentable(webView: tab.webView)
                                .id(tab.id)
                        }

                        // Selection overlay for area screenshots
                        if let dest = selectionDestination {
                            ScreenshotSelectionOverlay(
                                webView: tab.webView,
                                destination: dest,
                                sourceURL: tab.state.currentURL?.absoluteString
                            ) {
                                selectionDestination = nil
                            }
                        }
                    }

                    // Bookmarks panel
                    if showBookmarks {
                        Divider().opacity(0.15)
                        BookmarksPanelView { url in
                            tab.webView.load(URLRequest(url: url))
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            } else {
                Spacer()
                ContentUnavailableView(
                    "No Tabs Open",
                    systemImage: "globe",
                    description: Text("Open a new tab to start browsing.")
                )
                Button("New Tab") { viewModel.newTab() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                Spacer()
            }
        }
        .sheet(isPresented: $showAddToPinned) {
            if let tab = viewModel.selectedTab, let url = tab.state.currentURL {
                PinnedSiteEditorSheet(
                    mode: .add,
                    initialName: tab.state.pageTitle,
                    initialURL: url.absoluteString
                )
            }
        }
        .onAppear {
            browserEnv.bookmarks.load()
        }
    }

    private func browserErrorView(_ error: String, tab: BrowserTab) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Failed to Load")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Button("Try Again") { tab.reload() }
                .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tab Bar

private struct BrowserTabBar: View {
    let tabs: [BrowserTab]
    let selectedTabID: String?
    let onSelect: (String) -> Void
    let onClose: (String) -> Void
    let onNewTab: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    tabItem(tab)
                }

                Button(action: onNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("New Tab")
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(.ultraThinMaterial)
    }

    private func tabItem(_ tab: BrowserTab) -> some View {
        let isSelected = tab.id == selectedTabID

        return Button { onSelect(tab.id) } label: {
            HStack(spacing: 4) {
                if tab.state.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.65)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: tab.state.isSecure ? "lock.fill" : "globe")
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 12)
                }

                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .leading)

                if tabs.count > 1 {
                    Button { onClose(tab.id) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Close Tab") { onClose(tab.id) }
                .disabled(tabs.count <= 1)
            if let url = tab.state.currentURL {
                Divider()
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
                Button("Open in Safari") { NSWorkspace.shared.open(url) }
            }
        }
    }
}
#endif
