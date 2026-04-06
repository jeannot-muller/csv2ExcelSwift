# csv2excel — Swift 6 macOS App

## Overview
Native macOS app that converts CSV/TSV/TXT files to Excel (.xlsx). Rewritten from a Rust/Tauri app. Uses SwiftUI with libxlsxwriter (vendored C library via git submodule).

## Build & Run
```bash
# Ensure submodule is present
git submodule update --init

# Generate Xcode project (after adding/removing source files)
xcodegen generate

# Build from command line
xcodebuild -project csv2excel.xcodeproj -scheme csv2excel -configuration Debug build

# Install to /Applications for testing (Open With, Services, etc.)
cp -R ~/Library/Developer/Xcode/DerivedData/csv2excel-*/Build/Products/Debug/csv2excel.app /Applications/

# Update libxlsxwriter
make update-lib
```

## Project Structure
- **project.yml** — xcodegen spec (regenerates csv2excel.xcodeproj). Sources auto-discovered from `csv2excel/` directory.
- **Config.xcconfig** — single source of truth for `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
- **csv2excel.entitlements** — sandbox entitlements (xcodegen manages this via `properties:` in project.yml)
- **csv2excel/** — app source
  - `csv2excelApp.swift` — App entry, AppDelegate (single instance, window reopen, file open handling), menu commands, keyboard shortcuts, custom About/Help windows
  - `AppState.swift` — `@Observable` state with explicit `save()` to UserDefaults (didSet unreliable with @Observable)
  - `Info.plist` — CFBundleDocumentTypes (csv/tsv/txt), URL scheme (csv2excel://), NSServices
  - `ExportPreset.swift` — Full export preset (sheet name, delimiter, encoding, metadata, colors, smart types, decimal style, header row)
  - `MetadataPreset.swift` — Metadata-only preset (document properties + colors)
  - `ColorHex.swift` — Color ↔ hex string conversion extension
  - **Views/** — SwiftUI views
    - `ContentView.swift` — Main UI built with ScrollView/VStack/GroupBox (not Form — Form's `.grouped` style has a fixed max width that doesn't expand with the window)
    - `MetadataSection.swift` — 2-column document properties editor with inline color pickers
    - `DecimalStylePicker.swift` — Number format picker (Auto/Dot/Comma decimal)
    - `AboutView.swift` — Custom About window (respects dark mode toggle)
  - **Services/** — CSVParser, XLSXWriter
  - **Models/** — (empty, can remove)
- **Vendor/libxlsxwriter/** — git submodule, C library for xlsx generation

## Known SourceKit Noise
SourceKit (LSP) reports false-positive "Cannot find X in scope" errors for cross-file types (e.g. `AppState`, `FileInputView`, `ExportPreset`) and Regex literals. These are not real errors — `xcodebuild` compiles the full target correctly. Ignore these diagnostics.

## Key Architecture Decisions
- **@Observable + explicit save()**: `didSet` doesn't reliably fire with `@Observable` macro. All state changes that need persistence must call `appState.save()`.
- **No Form — uses ScrollView/VStack/GroupBox**: The `.grouped` Form style has a hardcoded max content width on macOS that doesn't expand with the window. All sections use GroupBox for consistent full-width layout.
- **Security-scoped bookmarks**: Required for sandbox file access across app restarts. Entitlement `com.apple.security.files.bookmarks.app-scope` must be present.
- **Quick re-convert**: After first successful conversion, `hasConvertedOnce` flag (transient, not persisted) lets Cmd+R skip the save panel and re-convert to the same destination.
- **Default output directory**: Persisted via security-scoped bookmark. Priority: save-to-same-location > default output dir > source file dir.
- **Smart type detection**: Locale-aware number parsing with DecimalStyle (dot/comma decimal). Auto-detection uses CSV delimiter as signal (semicolon → comma-decimal). Leading zeros preserved as text. Large integers (>2^53) preserved as text.
- **Date detection**: Swift Regex-based (not DateFormatter) for Sendable safety. Supports ISO, European, US, text month names, time-only, 2-digit years. Region derived from DecimalStyle.
- **Header row + auto-filter**: Bold format + `worksheet_autofilter()`. Optional header background color via `format_set_bg_color()`.
- **Sheet tab color**: Via `worksheet_set_tab_color()`. Colors stored as hex strings for Codable compatibility.
- **Smart metadata from filename**: Auto-populates Title, Category, Keywords from filename/path on file load (single file only, empty fields only).
- **libxlsxwriter tmpdir**: Must use `NSTemporaryDirectory()` via `workbook_new_opt()` — default tmpdir is blocked by sandbox.
- **Drag & drop**: Uses NSView (`DropZoneView.swift`) overlay with `hitTest → nil` for click passthrough. SwiftUI's `.onDrop` doesn't work reliably.
- **File open from Finder**: `application(_:openFiles:)` in AppDelegate + `pendingFileURLs` static for cold launch + NotificationCenter for warm launch.
- **Single instance**: Checked in `applicationDidFinishLaunching` via `NSWorkspace.shared.runningApplications`.
- **Convert button**: Uses `.plain` buttonStyle with custom background — `.borderedProminent` disappears when window loses focus (SwiftUI bug).
- **Encoding detection**: BOM check (first 4 bytes only) then UTF-8 trial on 8KB sample, falls back to Windows-1252. User can override via EncodingPicker.
- **Excel limits**: Rows capped at 1,048,576, columns at 16,384.
- **Versioning**: `Config.xcconfig` is the single source of truth. Referenced by project.yml via `configFiles:`.
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
- [ ] Quick re-convert (Cmd+R second time skips save panel)
- [ ] Delimiter auto-detection (comma, semicolon, tab)
- [ ] Encoding auto-detection (UTF-8, Latin-1, Windows-1252)
- [ ] Manual encoding override updates preview instantly
- [ ] Smart type detection toggle (on=auto-detect, off=all text)
- [ ] European numbers: semicolon CSV with "16,44" → number in Excel
- [ ] Leading zeros preserved: "00412" stays as text
- [ ] Date detection: "2024-03-15" → date cell, "14:30:00" → time cell
- [ ] Header row: bold + auto-filter when "First row is header" is on
- [ ] Header color and sheet tab color applied in Excel
- [ ] Metadata fields written to xlsx
- [ ] Smart metadata: filename auto-populates Title/Category/Keywords
- [ ] Export presets save/apply all settings including colors
- [ ] Metadata presets save/apply document properties + colors
- [ ] Default output directory persists and pre-fills save panel
- [ ] Save next to source shows source dir path
- [ ] App persists state across restarts
- [ ] Source path cleared on fresh launch
- [ ] Window > Main Window (Cmd+0) reopens closed window
- [ ] Dock icon click reopens window
- [ ] Trash button resets all fields (with confirmation)
- [ ] Preview shows first 5 rows with row count
- [ ] About window respects dark mode toggle
- [ ] Batch mode: drop multiple files, convert all
