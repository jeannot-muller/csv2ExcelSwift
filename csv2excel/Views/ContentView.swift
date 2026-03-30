import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Files") {
                    FileInputView()
                }

                Section("Options") {
                    DelimiterPicker()
                    SheetNameField()
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

            if appState.sourcePath.isEmpty {
                ContentUnavailableView {
                    Label("No File Selected", systemImage: "doc.text")
                } description: {
                    Text("Drop a CSV file here, choose one, or open with \u{2318}O")
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
            DropZoneView { url in
                populateFromFile(url)
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
                populateFromFile(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileFromFinder)) { notification in
            guard let url = notification.object as? URL else { return }
            populateFromFile(url)
        }
    }

    private func populateFromFile(_ url: URL) {
        let path = url.path(percentEncoded: false)
        appState.sourcePath = path
        appState.sourceBookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let xlsxPath = (path as NSString).deletingPathExtension + ".xlsx"
        appState.destinationPath = xlsxPath
        // No destination bookmark — user must confirm via Save panel on convert
        appState.destinationBookmark = nil
        appState.delimiter = CSVParser.detectDelimiter(fileAt: path)
        appState.save()
    }
}
