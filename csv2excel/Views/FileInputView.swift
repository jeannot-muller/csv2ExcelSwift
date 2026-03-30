import SwiftUI
import AppKit

struct FileInputView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 12) {
            // CSV file input
            HStack {
                Label("CSV file", systemImage: "doc.text")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField("Select your CSV input file", text: $state.sourcePath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse...") {
                    selectCSVFile()
                }
            }

            // Excel file output
            HStack {
                Label("EXCEL file", systemImage: "square.and.arrow.down")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField("Select your XLSX output file", text: $state.destinationPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse...") {
                    selectExcelFile()
                }
            }
        }
    }

    private func selectCSVFile() {
        let panel = NSOpenPanel()
        panel.title = "Please select your CSV file"
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
        panel.title = "Please define your XLSX destination file"
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
