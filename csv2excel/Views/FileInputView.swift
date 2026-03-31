import SwiftUI
import AppKit

struct FileInputView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        LabeledContent("CSV Input") {
            HStack {
                Text(inputLabel)
                    .foregroundStyle(appState.sourcePath.isEmpty && appState.batchFiles.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(appState.sourcePath)
                Button("Choose...") {
                    selectCSVFiles()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCSVFile)) { _ in
            selectCSVFiles()
        }
    }

    private var inputLabel: String {
        if appState.isBatchMode {
            return "\(appState.batchFiles.count) files selected"
        }
        return appState.sourcePath.isEmpty ? "Drop file(s) or choose..." : appState.sourcePath
    }

    private func selectCSVFiles() {
        let panel = NSOpenPanel()
        panel.title = "Select CSV File(s)"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .init(filenameExtension: "csv")!,
            .init(filenameExtension: "txt")!,
            .init(filenameExtension: "tsv")!,
        ]
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        guard !urls.isEmpty else { return }

        NotificationCenter.default.post(name: .openFilesFromPicker, object: urls)
    }
}
