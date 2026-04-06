import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var showResetConfirmation = false
    @State private var showPresetManager = false
    @State private var showMetadataPresets = false
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    @Bindable var state = appState

                    // MARK: - Files
                    sectionHeader("Files")
                    GroupBox {
                        FileInputView()
                    }

                    // MARK: - Options
                    sectionHeader("Options")
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Preset")
                                Spacer()
                                Menu {
                                    if appState.presets.isEmpty {
                                        Text("No Saved Presets")
                                    } else {
                                        ForEach(appState.presets) { preset in
                                            Button {
                                                appState.applyPreset(preset)
                                            } label: {
                                                VStack(alignment: .leading) {
                                                    Text(preset.name)
                                                    Text("\(preset.sheetName) · \(preset.encoding) · \(preset.delimiter)")
                                                }
                                            }
                                        }
                                        Divider()
                                    }
                                    Button("Save Current as Preset…") {
                                        showPresetManager = true
                                    }
                                    if !appState.presets.isEmpty {
                                        Button("Manage Presets…") {
                                            showPresetManager = true
                                        }
                                    }
                                } label: {
                                    Label(
                                        appState.presets.isEmpty ? "No Presets" : "\(appState.presets.count) Preset\(appState.presets.count == 1 ? "" : "s")",
                                        systemImage: "slider.horizontal.3"
                                    )
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            }
                            .popover(isPresented: $showPresetManager) {
                                PresetManagerView()
                                    .environment(appState)
                            }
                            Divider()
                            HStack {
                                Text("Encoding")
                                Spacer()
                                EncodingPicker()
                                    .labelsHidden()
                            }
                            Divider()
                            HStack {
                                Text("Delimiter")
                                Spacer()
                                DelimiterPicker()
                                    .labelsHidden()
                            }
                            Divider()
                            HStack {
                                Text("Worksheet name")
                                TextField("Sheet1", text: $state.sheetName)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: appState.sheetName) { _, newValue in
                                        let invalid = CharacterSet(charactersIn: "/\\?*:[]'")
                                        let filtered = String(newValue.unicodeScalars.filter { !invalid.contains($0) })
                                        let truncated = String(filtered.prefix(31))
                                        if truncated != newValue { appState.sheetName = truncated }
                                        appState.save()
                                    }
                                Toggle("First row is header", isOn: $state.hasHeaderRow)
                                    .onChange(of: appState.hasHeaderRow) { appState.save() }
                                    .fixedSize()
                            }
                            Divider()
                            HStack {
                                Toggle("Smart type detection", isOn: $state.smartTypes)
                                    .onChange(of: appState.smartTypes) { appState.save() }
                                    .fixedSize()
                                Spacer()
                                Text("Number format")
                                    .foregroundStyle(.secondary)
                                DecimalStylePicker()
                                    .labelsHidden()
                                    .fixedSize()
                                    .disabled(appState.smartTypes)
                            }
                            Divider()
                            HStack {
                                Toggle("Save next to source file", isOn: $state.saveToSameLocation)
                                    .onChange(of: appState.saveToSameLocation) { appState.save() }
                                    .fixedSize()
                                Spacer()
                                Text(outputLocationLabel)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if !appState.saveToSameLocation && !appState.defaultOutputDirectory.isEmpty {
                                    Button {
                                        appState.defaultOutputDirectory = ""
                                        appState.defaultOutputBookmark = nil
                                        appState.save()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if !appState.saveToSameLocation {
                                    Button("Choose…") {
                                        chooseDefaultOutputDirectory()
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding(4)
                    }

                    // MARK: - Document Properties
                    HStack {
                        sectionHeader("Document Properties")
                        Spacer()
                        if !appState.xlsxTitle.isEmpty || !appState.xlsxSubject.isEmpty ||
                           !appState.xlsxAuthor.isEmpty || !appState.xlsxManager.isEmpty ||
                           !appState.xlsxCompany.isEmpty || !appState.xlsxCategory.isEmpty ||
                           !appState.xlsxKeywords.isEmpty || !appState.xlsxComment.isEmpty ||
                           !appState.headerColor.isEmpty || !appState.sheetTabColor.isEmpty {
                            Button {
                                appState.clearMetadata()
                            } label: {
                                Label("Clear All", systemImage: "xmark.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                        Button {
                            showMetadataPresets = true
                        } label: {
                            Label("Presets", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .popover(isPresented: $showMetadataPresets) {
                            MetadataPresetView()
                                .environment(appState)
                        }
                    }
                    GroupBox {
                        MetadataSection()
                            .padding(4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            Divider()

            if appState.isBatchMode {
                BatchFileListView()
                    .environment(appState)
            } else if appState.sourcePath.isEmpty {
                ContentUnavailableView {
                    Label("No File Selected", systemImage: "doc.text")
                } description: {
                    Text("Drop CSV file(s) here, choose one, or open with \u{2318}O")
                }
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
            } else {
                CSVPreviewView()
                    .environment(appState)
            }

            Spacer(minLength: 0)

            Divider()
            ConvertButton()
            FooterBar()
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    appState.isDarkTheme.toggle()
                    appState.save()
                } label: {
                    Image(systemName: appState.isDarkTheme ? "sun.max" : "moon")
                }
                .help("Toggle Appearance")

                Button {
                    openWindow(id: "help")
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("Help")

                Button {
                    resetWindowSize()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Standard Size")

                Button {
                    showResetConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Reset All Fields")
                .confirmationDialog("Reset all fields?", isPresented: $showResetConfirmation) {
                    Button("Reset", role: .destructive) {
                        appState.reset()
                    }
                }
            }
        }
        .overlay {
            DropZoneView { urls in
                populateFromURLs(urls)
            }
        }
        .navigationTitle("csv2excel")
        .onReceive(NotificationCenter.default.publisher(for: .openHelp)) { _ in
            openWindow(id: "help")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAbout)) { _ in
            openWindow(id: "about")
        }
        .onAppear {
            // Pick up files passed via "Open With" / dock drop on cold launch
            if let urls = AppDelegate.pendingFileURLs {
                AppDelegate.pendingFileURLs = nil
                populateFromURLs(urls)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileFromFinder)) { notification in
            guard let url = notification.object as? URL else { return }
            populateFromURLs([url])
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFilesFromPicker)) { notification in
            guard let urls = notification.object as? [URL], !urls.isEmpty else { return }
            // Clear pending to avoid double-fire on cold launch
            AppDelegate.pendingFileURLs = nil
            populateFromURLs(urls)
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetWindowSize)) { _ in
            resetWindowSize()
        }
    }

    private var outputLocationLabel: String {
        if appState.saveToSameLocation {
            if appState.sourcePath.isEmpty {
                return "No source file"
            }
            return (appState.sourcePath as NSString).deletingLastPathComponent
        } else {
            if appState.defaultOutputDirectory.isEmpty {
                return "Default output: None"
            }
            return (appState.defaultOutputDirectory as NSString).lastPathComponent
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func resetWindowSize() {
        guard let window = NSApp.keyWindow else { return }
        let standardSize = NSSize(width: 680, height: 920)
        let frame = window.frame
        let newOrigin = NSPoint(
            x: frame.midX - standardSize.width / 2,
            y: frame.midY - standardSize.height / 2
        )
        let newFrame = NSRect(origin: newOrigin, size: standardSize)
        window.setFrame(newFrame, display: true, animate: true)
    }

    private func populateMetadataFromURL(_ url: URL) {
        // Title: filename without extension, separators replaced, title-cased
        if appState.xlsxTitle.isEmpty {
            let stem = url.deletingPathExtension().lastPathComponent
            let cleaned = stem
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
            appState.xlsxTitle = cleaned.localizedCapitalized
        }

        // Category: parent folder name if not generic
        if appState.xlsxCategory.isEmpty {
            let parent = url.deletingLastPathComponent().lastPathComponent
            let genericFolders: Set<String> = [
                "downloads", "desktop", "documents", "tmp", "temp",
                "home", "users", "var", "private",
            ]
            if !genericFolders.contains(parent.lowercased()) && !parent.isEmpty && parent != "/" {
                appState.xlsxCategory = parent
            }
        }

        // Keywords: extract years and date patterns from filename
        if appState.xlsxKeywords.isEmpty {
            let stem = url.deletingPathExtension().lastPathComponent
            var keywords: [String] = []
            let yearRegex = /\b(19|20)\d{2}\b/
            for match in stem.matches(of: yearRegex) {
                keywords.append(String(match.output.0))
            }
            if !keywords.isEmpty {
                appState.xlsxKeywords = keywords.joined(separator: ", ")
            }
        }
    }

    private func chooseDefaultOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Default Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        appState.defaultOutputDirectory = url.path(percentEncoded: false)
        appState.defaultOutputBookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        appState.save()
    }

    private func populateFromURLs(_ urls: [URL]) {
        // Track in recent files (with security-scoped bookmarks)
        for url in urls {
            appState.addRecentFile(url: url)
        }

        if urls.count == 1, let url = urls.first {
            // Single file mode
            appState.batchFiles = []
            let path = url.path(percentEncoded: false)
            appState.sourcePath = path
            appState.sourceBookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let xlsxPath = (path as NSString).deletingPathExtension + ".xlsx"
            appState.destinationPath = xlsxPath
            appState.destinationBookmark = nil
            appState.hasConvertedOnce = false
            appState.encoding = "auto"

            if let result = CSVParser.detectAndPreview(fileAt: path, encodingTag: appState.encoding) {
                appState.delimiter = result.delimiter
                appState.cachedPreviewRows = result.previewRows
                appState.cachedTotalRows = result.totalLines
            } else {
                appState.delimiter = "comma"
                appState.cachedPreviewRows = []
                appState.cachedTotalRows = 0
            }
            populateMetadataFromURL(url)
        } else {
            // Batch mode
            appState.sourcePath = ""
            appState.sourceBookmark = nil
            appState.destinationPath = ""
            appState.destinationBookmark = nil
            appState.cachedPreviewRows = []
            appState.cachedTotalRows = 0
            appState.batchFiles = urls.map { BatchFile(url: $0) }
        }
        appState.save()
    }
}
