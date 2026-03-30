import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var showImprint = false

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

            ConvertButton()

            FooterBar()
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    showImprint.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("Imprint")
                .popover(isPresented: $showImprint, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Imprint").font(.headline)
                        Divider()
                        Text("Dr. Jeannot Muller")
                        Text("c/o TECcompanion GmbH")
                        Text("Alexander-Pachmann-Str. 15")
                        Text("85716 Unterschleißheim")
                    }
                    .padding()
                    .frame(width: 240)
                }

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
                    appState.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset All Fields")
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
