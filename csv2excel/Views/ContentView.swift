import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var showResetConfirmation = false
    @State private var showPresetManager = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Files") {
                    FileInputView()
                }

                Section {
                    @Bindable var state = appState
                    EncodingPicker()
                    DelimiterPicker()
                    SheetNameField()
                    Toggle("Save next to source file", isOn: $state.saveToSameLocation)
                        .onChange(of: appState.saveToSameLocation) { appState.save() }
                } header: {
                    HStack {
                        Text("Options")
                        Spacer()
                        Button {
                            showPresetManager = true
                        } label: {
                            Label("Presets", systemImage: "slider.horizontal.3")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .popover(isPresented: $showPresetManager) {
                            PresetManagerView()
                                .environment(appState)
                        }
                    }
                }

                Section {
                    MetadataSection()
                } header: {
                    Text("Document Properties")
                } footer: {
                    Text("These fields are embedded as metadata in the Excel file.")
                        .foregroundStyle(.tertiary)
                }
            }
            .formStyle(.grouped)

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
        .onAppear {
            // Pick up file passed via "Open With" on cold launch
            if let url = AppDelegate.pendingFileURL {
                AppDelegate.pendingFileURL = nil
                populateFromURLs([url])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileFromFinder)) { notification in
            guard let url = notification.object as? URL else { return }
            populateFromURLs([url])
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFilesFromPicker)) { notification in
            guard let urls = notification.object as? [URL], !urls.isEmpty else { return }
            populateFromURLs(urls)
        }
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
