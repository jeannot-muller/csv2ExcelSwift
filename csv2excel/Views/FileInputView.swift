import SwiftUI
import AppKit

struct FileInputView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        LabeledContent("CSV Input") {
            HStack {
                Text(appState.sourcePath.isEmpty ? "No file selected" : (appState.sourcePath as NSString).lastPathComponent)
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

        LabeledContent("Excel Output") {
            HStack {
                Text(appState.destinationPath.isEmpty ? "No file selected" : (appState.destinationPath as NSString).lastPathComponent)
                    .foregroundStyle(appState.destinationPath.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(appState.destinationPath)
                Button("Choose...") {
                    selectExcelFile()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .setOutputFile)) { _ in
            selectExcelFile()
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

    private func selectExcelFile() {
        let panel = NSSavePanel()
        panel.title = "Set Excel Output File"
        panel.allowedContentTypes = [
            .init(filenameExtension: "xlsx")!,
        ]
        if panel.runModal() == .OK, let url = panel.url {
            appState.destinationPath = url.path(percentEncoded: false)
            appState.destinationBookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            appState.save()
        }
    }
}
