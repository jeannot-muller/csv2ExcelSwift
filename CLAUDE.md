# csv2excel — Swift 6 macOS App

## Overview
Native macOS app that converts CSV/TSV/TXT files to Excel (.xlsx). Rewritten from a Rust/Tauri app. Uses SwiftUI with libxlsxwriter (vendored C library via git submodule).

## Build & Run
```bash
# Ensure submodule is present
git submodule update --init

# Generate Xcode project (after changing project.yml)
xcodegen generate

# Build from command line
xcodebuild -project csv2excel.xcodeproj -scheme csv2excel -configuration Debug build

# Install to /Applications for testing (Open With, Services, etc.)
cp -R ~/Library/Developer/Xcode/DerivedData/csv2excel-*/Build/Products/Debug/csv2excel.app /Applications/

# Update libxlsxwriter
make update-lib
```

## Project Structure
- **project.yml** — xcodegen spec (regenerates csv2excel.xcodeproj)
- **Config.xcconfig** — single source of truth for `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
- **csv2excel.entitlements** — sandbox entitlements (xcodegen manages this via `properties:` in project.yml)
- **csv2excel/** — app source
  - `csv2excelApp.swift` — App entry, AppDelegate (single instance, window reopen, file open handling), menu commands, keyboard shortcuts
  - `AppState.swift` — `@Observable` state with explicit `save()` to UserDefaults (didSet unreliable with @Observable)
  - `Info.plist` — CFBundleDocumentTypes (csv/tsv/txt), URL scheme (csv2excel://), NSServices
  - **Views/** — SwiftUI views
  - **Services/** — CSVParser, XLSXWriter, MiniZIP (unused, can remove)
  - **Models/** — (empty, can remove)
- **Vendor/libxlsxwriter/** — git submodule, C library for xlsx generation

## Key Architecture Decisions
- **@Observable + explicit save()**: `didSet` doesn't reliably fire with `@Observable` macro. All state changes that need persistence must call `appState.save()`.
- **Security-scoped bookmarks**: Required for sandbox file access across app restarts. Entitlement `com.apple.security.files.bookmarks.app-scope` must be present.
- **No output file field**: Save panel shown on every Convert click. Avoids sandbox permission issues and simplifies the flow.
- **libxlsxwriter tmpdir**: Must use `NSTemporaryDirectory()` via `workbook_new_opt()` — default tmpdir is blocked by sandbox.
- **Drag & drop**: Uses NSView (`DropZoneView.swift`) overlay with `hitTest → nil` for click passthrough. SwiftUI's `.onDrop` doesn't work reliably on Forms.
- **File open from Finder**: `application(_:openFiles:)` in AppDelegate + `pendingFileURL` static for cold launch + NotificationCenter for warm launch.
- **Single instance**: Checked in `applicationDidFinishLaunching` via `NSWorkspace.shared.runningApplications`.
- **Convert button**: Uses `.plain` buttonStyle with custom background — `.borderedProminent` disappears when window loses focus (SwiftUI bug).
- **Encoding detection**: Auto-detects via BOM then UTF-8 trial, falls back to Windows-1252. User can override via EncodingPicker. Preview updates live on encoding change.
- **Versioning**: `Config.xcconfig` is the single source of truth — edit in Xcode only. Referenced by project.yml via `configFiles:` and `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)`.
- **Bundle ID**: `com.jeannot-muller.csv2excel` — must match the original Tauri app's App Store Connect record.

## Entitlements (managed by xcodegen)
- `com.apple.security.app-sandbox` — required for MAS
- `com.apple.security.files.user-selected.read-write` — file picker access
- `com.apple.security.files.bookmarks.app-scope` — persist file access across launches
- `com.apple.security.network.client` — external links

## Testing Checklist
- [ ] Drop CSV/TSV/TXT file on window
- [ ] Choose file via button and Cmd+O
- [ ] Right-click CSV in Finder → Open With → csv2excel
- [ ] Convert with Save panel
- [ ] Delimiter auto-detection (comma, semicolon, tab)
- [ ] Encoding auto-detection (UTF-8, Latin-1, Windows-1252)
- [ ] Manual encoding override updates preview instantly
- [ ] Metadata fields written to xlsx
- [ ] App persists state across restarts (theme, encoding, delimiter, sheet name, metadata)
- [ ] Source path cleared on fresh launch
- [ ] Window > Main Window (Cmd+0) reopens closed window
- [ ] Dock icon click reopens window
- [ ] Trash button resets all fields (with confirmation)
- [ ] Preview shows first 5 rows with row count
- [ ] Single file drop only (multiple rejected)
