import SwiftUI
import AppKit

struct FileInputView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        LabeledContent("CSV Input") {
            HStack {
                Text(appState.sourcePath.isEmpty ? "Drop file or choose..." : appState.sourcePath)
                    .foregroundStyle(appState.sourcePath.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(appState.sourcePath)
                Button("Choose...") {
                    selectCSVFile()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCSVFile)) { _ in
            selectCSVFile()
        }
    }

    private func selectCSVFile() {
        let panel = NSOpenPanel()
        panel.title = "Select CSV File"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .init(filenameExtension: "csv")!,
            .init(filenameExtension: "txt")!,
            .init(filenameExtension: "tsv")!,
        ]
        if panel.runModal() == .OK, let url = panel.url {
            appState.sourcePath = url.path(percentEncoded: false)
            appState.sourceBookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            appState.delimiter = CSVParser.detectDelimiter(fileAt: appState.sourcePath)
            appState.save()
        }
    }
}
