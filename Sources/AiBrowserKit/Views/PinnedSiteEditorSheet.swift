#if canImport(AppKit)
import SwiftUI

/// Sheet for adding or editing a pinned site.
public struct PinnedSiteEditorSheet: View {
    @Environment(BrowserEnvironment.self) private var browserEnv
    @Environment(\.dismiss) private var dismiss

    /// Determines whether the sheet is creating or editing a site.
    public enum Mode {
        /// Creates a new pinned site.
        case add
        /// Edits an existing pinned site.
        case edit(PinnedSite)
    }

    /// Current editor mode.
    public let mode: Mode
    /// Default name used when opening the sheet in add mode.
    public var initialName: String = ""
    /// Default URL used when opening the sheet in add mode.
    public var initialURL: String = ""

    @State private var name: String = ""
    @State private var urlString: String = ""
    @State private var iconName: String = "globe"
    @State private var useFavicon: Bool = true
    @State private var colorHex: String = ""
    @State private var selectedGroupID: String? = nil
    @State private var newGroupName: String = ""
    @State private var showNewGroupField: Bool = false
    @State private var autoRefreshEnabled: Bool = false
    @State private var autoRefreshSeconds: Int = 60

    @State private var faviconPreview: NSImage?
    @State private var isFetchingFavicon: Bool = false
    private let previewItemID = UUID().uuidString

    /// Creates the pinned-site editor sheet.
    ///
    /// - Parameters:
    ///   - mode: Add or edit mode.
    ///   - initialName: Default name in add mode.
    ///   - initialURL: Default URL in add mode.
    public init(mode: Mode, initialName: String = "", initialURL: String = "") {
        self.mode = mode
        self.initialName = initialName
        self.initialURL = initialURL
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editingItemID: String? {
        if case .edit(let site) = mode { return site.id }
        return nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !urlString.trimmingCharacters(in: .whitespaces).isEmpty
        && URL(string: normalizedURL) != nil
    }

    private var normalizedURL: String {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty && !s.hasPrefix("http://") && !s.hasPrefix("https://") {
            s = "https://\(s)"
        }
        return s
    }

    /// Renders pinned-site fields, icon picker, and save actions.
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Pinned Site" : "Pin to Sidebar")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().opacity(0.1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fieldSection("Name") {
                        TextField("My Dashboard", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    fieldSection("URL") {
                        HStack(spacing: 8) {
                            TextField("https://example.com or localhost:3000", text: $urlString)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if name.isEmpty, let url = URL(string: normalizedURL) {
                                        name = url.host() ?? ""
                                    }
                                    fetchFaviconPreview()
                                }
                            Button {
                                fetchFaviconPreview()
                            } label: {
                                Group {
                                    if isFetchingFavicon {
                                        ProgressView().controlSize(.small).scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.down.circle").font(.system(size: 14))
                                    }
                                }
                                .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .help("Fetch favicon")
                            .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    fieldSection("Icon") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Toggle("Use site favicon", isOn: $useFavicon)
                                    .toggleStyle(.switch)
                                    .controlSize(.small)

                                if useFavicon {
                                    if let faviconPreview {
                                        Image(nsImage: faviconPreview)
                                            .resizable()
                                            .interpolation(.high)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 24, height: 24)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        Text("Favicon loaded")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    } else if isFetchingFavicon {
                                        ProgressView().controlSize(.small)
                                        Text("Fetching...")
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text("Enter a URL and press Return to fetch")
                                            .font(.caption).foregroundStyle(.tertiary)
                                    }
                                }
                            }

                            if !useFavicon {
                                SFSymbolPicker(selectedSymbol: $iconName)
                            }
                        }
                    }

                    fieldSection("Group (optional)") {
                        groupPicker
                    }

                    fieldSection("Color Dot (optional)") {
                        HStack(spacing: 12) {
                            ForEach(presetColors, id: \.self) { hex in colorButton(hex) }
                            Divider().frame(height: 20)
                            TextField("#FF5733", text: $colorHex)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }

                    fieldSection("Auto-Refresh") {
                        HStack(spacing: 12) {
                            Toggle("", isOn: $autoRefreshEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)

                            if autoRefreshEnabled {
                                Picker("Interval", selection: $autoRefreshSeconds) {
                                    Text("15s").tag(15)
                                    Text("30s").tag(30)
                                    Text("1m").tag(60)
                                    Text("5m").tag(300)
                                    Text("15m").tag(900)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 300)
                            } else {
                                Text("Disabled").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider().opacity(0.1)

            HStack {
                if isEditing {
                    Button(role: .destructive) {
                        if case .edit(let site) = mode {
                            browserEnv.webViewCache.evict(id: site.id)
                            browserEnv.favicons.evict(itemID: site.id)
                            browserEnv.pinnedSites.removeSite(id: site.id)
                        }
                        dismiss()
                    } label: {
                        Text("Delete").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Save" : "Add to Sidebar") {
                    saveItem()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding(20)
        }
        .frame(width: 520, height: 640)
        .onAppear {
            loadInitialValues()
            if !urlString.isEmpty { fetchFaviconPreview() }
        }
    }

    // MARK: - Group Picker

    private var groupPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                groupChip(label: "None", isActive: selectedGroupID == nil) {
                    selectedGroupID = nil
                    showNewGroupField = false
                }

                ForEach(browserEnv.pinnedSites.groups) { group in
                    groupChip(label: group.name, icon: group.iconName, isActive: selectedGroupID == group.id) {
                        selectedGroupID = group.id
                        showNewGroupField = false
                    }
                }

                groupChip(label: "New...", icon: "plus", isActive: showNewGroupField) {
                    showNewGroupField = true
                    selectedGroupID = nil
                }
            }

            if showNewGroupField {
                HStack(spacing: 8) {
                    TextField("Group name", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                    Button("Create") {
                        createGroupAndAssign()
                    }
                    .buttonStyle(.bordered)
                    .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func groupChip(label: String, icon: String? = nil, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 10)) }
                Text(label).font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func createGroupAndAssign() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let group = PinnedSiteGroup(name: trimmed)
        browserEnv.pinnedSites.addGroup(group)
        selectedGroupID = group.id
        showNewGroupField = false
        newGroupName = ""
    }

    // MARK: - Data

    private func loadInitialValues() {
        switch mode {
        case .add:
            name = initialName
            urlString = initialURL
        case .edit(let site):
            name = site.name
            urlString = site.urlString
            iconName = site.iconName
            useFavicon = site.useFavicon
            colorHex = site.colorHex ?? ""
            selectedGroupID = site.groupID
            if let secs = site.autoRefreshSeconds {
                autoRefreshEnabled = true
                autoRefreshSeconds = secs
            }
            faviconPreview = browserEnv.favicons.cachedImage(for: site.id)
        }
    }

    private func fetchFaviconPreview() {
        let url = normalizedURL
        guard !url.isEmpty, URL(string: url) != nil else { return }
        isFetchingFavicon = true
        let targetID = editingItemID ?? previewItemID
        Task {
            let image = await browserEnv.favicons.fetchFavicon(for: url, itemID: targetID)
            faviconPreview = image
            isFetchingFavicon = false
        }
    }

    private func saveItem() {
        let trimmedColor = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .add:
            let itemID = UUID().uuidString
            let site = PinnedSite(
                id: itemID,
                name: name.trimmingCharacters(in: .whitespaces),
                urlString: normalizedURL,
                iconName: iconName.isEmpty ? "globe" : iconName,
                useFavicon: useFavicon,
                colorHex: trimmedColor.isEmpty ? nil : trimmedColor,
                groupID: selectedGroupID,
                autoRefreshSeconds: autoRefreshEnabled ? autoRefreshSeconds : nil
            )
            browserEnv.pinnedSites.addSite(site)
            if useFavicon, faviconPreview != nil {
                Task {
                    browserEnv.favicons.evict(itemID: previewItemID)
                    _ = await browserEnv.favicons.fetchFavicon(for: normalizedURL, itemID: itemID)
                }
            }

        case .edit(let existing):
            let updated = PinnedSite(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                urlString: normalizedURL,
                iconName: iconName.isEmpty ? "globe" : iconName,
                useFavicon: useFavicon,
                colorHex: trimmedColor.isEmpty ? nil : trimmedColor,
                groupID: selectedGroupID,
                autoRefreshSeconds: autoRefreshEnabled ? autoRefreshSeconds : nil,
                sortOrder: existing.sortOrder
            )
            browserEnv.pinnedSites.updateSite(updated)
        }
    }

    // MARK: - Helpers

    private func fieldSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).fontWeight(.medium)
            content()
        }
    }

    private let presetColors = [
        "#FF5733", "#3498DB", "#2ECC71", "#F39C12", "#9B59B6", "#1ABC9C", "#E74C3C",
    ]

    private func colorButton(_ hex: String) -> some View {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let isActive = colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased() == clean.lowercased()
        let val = UInt64(clean, radix: 16) ?? 0
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0

        return Button {
            colorHex = isActive ? "" : hex
        } label: {
            Circle()
                .fill(Color(red: r, green: g, blue: b))
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.white, lineWidth: isActive ? 2 : 0))
                .shadow(color: isActive ? Color(red: r, green: g, blue: b).opacity(0.5) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }
}
#endif
