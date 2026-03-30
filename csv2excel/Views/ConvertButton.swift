import SwiftUI
import AppKit

struct ConvertButton: View {
    @Environment(AppState.self) private var appState
    @State private var isConverting = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var alertIsError = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                convert()
            } label: {
                Label("Convert", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isConverting ? Color.accentColor.opacity(0.5) : Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isConverting)
            .keyboardShortcut("r")

            if isConverting {
                ProgressView()
                    .controlSize(.small)
                Text("Converting...")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .onReceive(NotificationCenter.default.publisher(for: .triggerConvert)) { _ in
            convert()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func convert() {
        guard !isConverting else { return }

        let source = appState.sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)

        if source.isEmpty {
            showError("Missing CSV File", "Select a CSV input file first.")
            return
        }
        if appState.sheetName.isEmpty {
            showError("Invalid Sheet Name", "Worksheet name cannot be blank.")
            return
        }
        if !FileManager.default.fileExists(atPath: source) {
            showError("File Not Found", "The source CSV file no longer exists at the specified path.")
            return
        }

        // Always show Save panel — pre-filled with source name + .xlsx
        let suggestedName = ((source as NSString).lastPathComponent as NSString).deletingPathExtension + ".xlsx"
        let suggestedDir = (source as NSString).deletingLastPathComponent
        let panel = NSSavePanel()
        panel.title = "Save Excel File"
        panel.nameFieldStringValue = suggestedName
        panel.directoryURL = URL(fileURLWithPath: suggestedDir)
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        guard panel.runModal() == .OK, let destURL = panel.url else { return }

        appState.destinationPath = destURL.path(percentEncoded: false)
        appState.destinationBookmark = try? destURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        appState.save()

        isConverting = true

        let delimiter = appState.delimiter
        let sheetName = appState.sheetName
        let properties = XLSXDocProperties(
            title: appState.xlsxTitle,
            subject: appState.xlsxSubject,
            author: appState.xlsxAuthor,
            manager: appState.xlsxManager,
            company: appState.xlsxCompany,
            category: appState.xlsxCategory,
            keywords: appState.xlsxKeywords,
            comment: appState.xlsxComment
        )

        let sourceURL = appState.resolveSourceURL()
        let destBookmarkURL = appState.resolveDestinationURL()
        let sourceAccess = sourceURL?.startAccessingSecurityScopedResource() ?? false
        let destAccess = destBookmarkURL?.startAccessingSecurityScopedResource() ?? false

        Task.detached {
            defer {
                if sourceAccess { sourceURL?.stopAccessingSecurityScopedResource() }
                if destAccess { destBookmarkURL?.stopAccessingSecurityScopedResource() }
            }
            let start = ContinuousClock.now
            do {
                let rows = try CSVParser.parse(fileAt: source, delimiter: delimiter)
                try XLSXWriter.write(
                    rows: rows,
                    sheetName: sheetName,
                    properties: properties,
                    to: destURL
                )
                let elapsed = start.duration(to: .now)
                let seconds = Double(elapsed.components.attoseconds) / 1e18 + Double(elapsed.components.seconds)
                let duration = String(format: "%.4f s", seconds)

                await MainActor.run {
                    appState.runTime = duration
                    appState.save()
                    isConverting = false
                    showSuccess("Conversion Complete", "File created successfully in \(duration).")
                }
            } catch {
                await MainActor.run {
                    appState.runTime = "ERR"
                    appState.save()
                    isConverting = false
                    showError("Conversion Failed", error.localizedDescription)
                }
            }
        }
    }

    private func showError(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        alertIsError = true
        showAlert = true
    }

    private func showSuccess(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        alertIsError = false
        showAlert = true
    }
}
