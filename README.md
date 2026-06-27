# AiBrowserKit

SwiftUI + WKWebView browser components for **macOS agent applications**. Embed a full multi-tab browser panel, pinned-site sidebar, bookmarks, JS console capture, and screenshot tooling — or pull in the WebKit primitives alone and build custom chrome around your own automation bridge.

**Platforms:** macOS 26+ (full UI) · iOS 17+ / visionOS 1+ (WebKit building blocks only)  
**Language:** Swift 6.0+  
**Dependencies:** none (system frameworks only)

---

## Features

| Feature | Description |
|---------|-------------|
| **Multi-tab browser** | `BrowserView` + `BrowserViewModel` + `BrowserTab` — tab bar, progress, smart URL bar |
| **Bookmarks** | Folder tree, JSONL persistence, slide-out panel, horizontal bookmark bar |
| **Pinned sites** | Sidebar tiles with groups, SF Symbols, favicons, auto-refresh, localhost reachability |
| **Console capture** | Intercepts `console.log/info/warn/error/debug` into a ring buffer; detached panel or inline view |
| **Screenshots** | Visible-area snapshot or drag-select region → clipboard, file, or host clipboard callback |
| **Stealth injection** | Document-start script to reduce automation fingerprinting (see [Security](#security--privacy)) |
| **Favicon cache** | Disk + memory cache with Google S2 fallback |
| **Theme override** | Cycle system / light / dark appearance per web view |

---

## Platform support

AiBrowserKit declares iOS and visionOS in `Package.swift`, but the **full browser UI is macOS-only** (`#if canImport(AppKit)`). Cross-platform targets expose WebKit helpers and bookmark models for custom integrations.

| API / feature | macOS | iOS / visionOS |
|---------------|:-----:|:--------------:|
| `BrowserView`, `BrowserEnvironment` | ✅ | — |
| Pinned sites UI, screenshots, console panel | ✅ | — |
| `WebViewFactory`, `WebViewRepresentable`, `WebViewState` | ✅ | ✅ |
| `BookmarkService`, `BookmarkBarView`, `ConsoleLogView` | ✅ | ✅ |
| `BrowserTab`, `BrowserViewModel` | ✅ | — |

**Deployment target:** macOS 26.0 (matches Apple Intelligence / Tahoe SDK apps in the NerdSnipe stack). Lower the target in `Package.swift` if you need broader macOS support — most APIs are standard WebKit/SwiftUI.

---

## Installation

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/NerdSnipe-Inc/AiBrowserKit.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: ["AiBrowserKit"]
    ),
]
```

### Local path dependency (monorepo / CI)

Point `Package.swift` at a sibling checkout:

```
MyWorkspace/
  MyApp/
  packages/AiBrowserKit/   ← ../packages/AiBrowserKit
```

---

## Quick start — full browser (macOS)

Create a shared `BrowserEnvironment` at app root and inject it into `BrowserView`:

```swift
import SwiftUI
import AiBrowserKit

@main
struct MyApp: App {
    @State private var browserEnv = BrowserEnvironment()  // optional storageDirectory:

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environment(browserEnv)
        }
    }
}
```

### Host clipboard callback

Wire screenshots and “copy to app clipboard” actions into your host store:

```swift
browserEnv.onAddToClipboard = { content in
    switch content.kind {
    case .text(let string):
        // Add to your app-wide clipboard / memory pipeline
        break
    case .image(let nsImage):
        // Handle NSImage from visible or region screenshot
        break
    }
}
```

Use `ScreenshotDestination.hostClipboard` or the navigation bar actions that call `onAddToClipboard` when set.

---

## Quick start — custom panel + agent bridge

For agent apps that drive the browser via tools (`browserNavigate`, `browserGetContent`, `browserExecute`), you typically **do not** use `BrowserView`. Instead:

1. Create a `WKWebView` with `WebViewFactory.makeWebView(state:consoleStore:)`.
2. Render it with `WebViewRepresentable(webView:)`.
3. Register the active web view with your host controller when the tab becomes visible.

```swift
import AiBrowserKit
import WebKit

let state = WebViewState()
let webView = WebViewFactory.makeWebView(state: state, consoleStore: myConsoleStore)

// In SwiftUI:
WebViewRepresentable(webView: webView)

// When this tab is active, register for agent tools:
HostBrowserController.shared.webView = webView
HostBrowserController.shared.webViewState = state
```

Implement navigation, content extraction, and JS evaluation in your host app’s browser controller. AiBrowserKit supplies the web view, state, and optional bookmark bar.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Views (SwiftUI — macOS: BrowserView, PinnedSiteView, …)     │
└──────────────────────────┬──────────────────────────────────┘
                           │ @Environment(BrowserEnvironment.self)
┌──────────────────────────▼──────────────────────────────────┐
│ BrowserEnvironment                                           │
│  browserVM · bookmarks · favicons · pinnedSites · console     │
└──────────┬─────────────────┬─────────────────┬──────────────┘
           │                 │                 │
    ViewModels          Services            Models
 BrowserViewModel    BookmarkService     BrowserTab
 PinnedSiteStore     FaviconService      BrowserBookmark
                     PinnedSiteWebViewCache  PinnedSite
                                           ConsoleLogStore
                           │
┌──────────────────────────▼──────────────────────────────────┐
│ WebKit/                                                      │
│  WebViewFactory · WebViewState · WebViewCoordinator          │
│  WebViewRepresentable · StealthScript (internal)             │
└─────────────────────────────────────────────────────────────┘
```

### Public types (selected)

| Type | Role |
|------|------|
| `BrowserEnvironment` | Root `@Observable` container; inject at app root |
| `BrowserViewModel` | Tab list, selection, new/close tab |
| `BrowserTab` | One tab: `WKWebView` + `WebViewState` + URL bar logic |
| `WebViewState` | Observable page state (URL, title, loading, back/forward) |
| `WebViewFactory` | Creates configured `WKWebView` with stealth + console scripts |
| `BookmarkService` | JSONL bookmarks + JSON folders on disk |
| `PinnedSiteStore` | Pinned sites and groups persistence |
| `ConsoleLogStore` | Ring buffer (max 500 entries) for captured console output |
| `FaviconService` | Fetch and cache site favicons |

---

## Data storage

| Data | Default location | Configurable |
|------|------------------|:------------:|
| Bookmarks + folders | `~/Library/Application Support/AiBrowserKit/` | ✅ `BookmarkService(storageDirectory:)` |
| Pinned sites | `…/AiBrowserKit/pinned_sites.json` | ✅ `PinnedSiteStore(storageDirectory:)` or `BrowserEnvironment(storageDirectory:)` |
| Favicon cache | `…/AiBrowserKit/favicons/` | ✅ same |
| Bookmark UI state | `UserDefaults` key `aibrowserkit.bookmarks.expandedFolderIDs` | — |

Pass a single directory to `BrowserEnvironment(storageDirectory:)` to colocate all persisted browser data (bookmarks, pinned sites, favicons).

---

## Console

Console messages are captured when `WebViewFactory.makeWebView` receives a non-nil `ConsoleLogStore`. The factory injects a script that forwards `console.*` to the native `aiBrowserConsole` message handler.

**Detached panel (macOS):**

```swift
ConsoleWindowManager.shared.toggle(store: browserEnv.consoleStore)
```

**Inline:**

```swift
ConsoleLogView(store: browserEnv.consoleStore)
```

---

## Pinned sites

```swift
PinnedSiteView(site: site)
    .environment(browserEnv)
```

Supports groups, SF Symbol or favicon icons, color dots, optional auto-refresh interval, and a localhost reachability indicator (HEAD probe). `PinnedSiteWebViewCache` keeps live `WKWebView` instances per pinned site ID when switching sidebar selection.

---

## Stealth mode

`StealthScript` (injected at `.atDocumentStart`, all frames) attempts to reduce automation fingerprinting:

- Clears `navigator.webdriver`
- Spoofs plugins, permissions, vendor strings
- Adds canvas noise and WebGL vendor/renderer overrides
- Cleans exposed `window.webkit.messageHandlers` after console handler setup

This is **not** a guarantee against bot detection. Host apps should document ethical use, respect site terms of service, and apply their own URL policies for agent-driven navigation.

---

## Security & privacy

| Topic | Behavior |
|-------|----------|
| **Shared cookie jar** | All web views use `WKWebsiteDataStore.default()` — sessions are shared |
| **URL policy** | No built-in allowlist; `BrowserTab.navigate` accepts http(s), localhost, and `aibrowser://` |
| **JS execution** | Host apps can call `evaluateJavaScript` on registered web views — treat as privileged |
| **Favicon fallback** | Google S2 favicon API may leak visited hostnames |
| **User agent** | Hardcoded Safari-like strings (macOS 15.5 / iOS 18.5); update periodically |
| **Autoplay** | `mediaTypesRequiringUserActionForPlayback = []` |
| **TLS** | Standard WKWebView certificate validation only (no pinning) |

Agent integrations should validate URLs before navigation and never expose raw JS execution to untrusted model output without sandboxing.

---

## Package layout

```
Sources/AiBrowserKit/
├── Environment/     BrowserEnvironment, AiBrowserClipboardContent
├── Models/          BrowserTab, BrowserBookmark, PinnedSite, ConsoleEntry, …
├── ViewModels/      BrowserViewModel, PinnedSiteStore
├── Services/        BookmarkService, FaviconService, PinnedSiteWebViewCache
├── Utilities/       BrowserURLResolver, AiBrowserStorage
├── WebKit/          WebViewFactory, WebViewState, StealthScript
└── Views/           BrowserView, BookmarkBarView, ConsoleLogView, …

Tests/AiBrowserKitTests/
├── BrowserURLResolverTests.swift   URL bar resolution (unit)
├── ModelTests.swift                Codable models, theme override (unit)
├── BookmarkServiceTests.swift      JSONL persistence (unit)
├── PinnedSiteStoreTests.swift      Pinned sites persistence (unit)
├── ConsoleAndViewModelTests.swift  Console ring buffer, tabs, web view cache (unit)
├── FaviconServiceTests.swift       Disk cache read/evict (unit, macOS)
├── IntegrationTests.swift          Live WKWebView + network (integration, macOS)
├── TestSupport.swift               Temp storage helpers, integration gate
└── IntegrationTestGate             via `RUN_INTEGRATION_TESTS=1`
```

---

## Testing

AiBrowserKit ships an **`AiBrowserKitTests`** target with **unit** tests (always run) and **integration** tests (live `WKWebView`, network, disk I/O) gated on the `RUN_INTEGRATION_TESTS` environment variable.

### Quick commands

```bash
# Unit tests only (default CI on pull requests)
swift test
bash scripts/ci-test.sh unit

# Unit + integration (live WebKit + network)
RUN_INTEGRATION_TESTS=1 swift test
bash scripts/ci-test.sh integration

# Contributor policy only (no Swift tests)
bash scripts/ci-test.sh policy
bash scripts/check-no-cursor-attribution.sh
```

The policy check scans tracked sources and commit messages for prohibited Cursor contributor attribution (see `scripts/check-no-cursor-attribution.sh`).

On NerdSnipe self-hosted runners, `scripts/ci-test.sh` auto-selects **Xcode-beta** when present (`~/Applications/Xcode-beta.app`).

### Test inventory

| Suite | Type | What it covers |
|-------|------|----------------|
| `BrowserURLResolver` | Unit | URL bar: schemes, localhost, bare domains, Google search fallback |
| `Model Codable & computed properties` | Unit | `BrowserBookmark`, `PinnedSite`, `PinnedSiteStoreData`, legacy decode |
| `WebViewThemeOverride` | Unit | Theme cycle icons/labels |
| `BookmarkService persistence` | Unit | Add, dedupe, toggle, folders, remove; JSONL round-trip |
| `PinnedSiteStore persistence` | Unit | Add/remove/update, visibility, append sort order |
| `ConsoleLogStore` | Unit | Append, clear, 500-entry ring buffer |
| `BrowserViewModel tab management` | Unit | Initial tab, new/close tab, last-tab guard |
| `PinnedSiteWebViewCache` | Unit | Per-site web view reuse and evict |
| `FaviconService — disk cache` | Unit (macOS) | Load PNG from cache dir, evict |
| `WebViewFactory — live WKWebView` | Integration | Load example.com, console capture, config defaults |
| `BrowserTab — live navigation` | Integration | Domain navigation, Google search fallback |
| `FaviconService — network` | Integration | Fetch + cache favicon for example.com |
| `BrowserEnvironment — colocated storage` | Integration | Unified storage directory round-trip |

Integration suites use `@Suite(..., .enabled(if: IntegrationTestGate.isEnabled))` so they are **skipped** (not failed) when the env var is unset.

### CI

GitHub Actions workflow (`.github/workflows/ci.yml`):

- **Every PR / push:** `scripts/ci-test.sh unit`
- **`main` push or manual dispatch** (`run_integration: true`): `scripts/ci-test.sh integration`

Host apps that embed a custom browser panel should add their own integration tests for tool-driven navigation; AiBrowserKit tests cover the package in isolation.

---

## Roadmap

- [x] Package test target
- [ ] iOS `BrowserView` port or explicit macOS-only product split
- [ ] Document minimum macOS version after SDK stabilization

---

## Related packages

| Package | Relationship |
|---------|--------------|
| [AIChatKit](https://github.com/NerdSnipe-Inc/AIChatKit) | Chat UI + providers; pairs with agent browser tools |
| [AIChatKitMLX](https://github.com/NerdSnipe-Inc/AIChatKitMLX) | On-device MLX inference for agent apps |

---

## License

Copyright © NerdSnipe Inc. All rights reserved.
