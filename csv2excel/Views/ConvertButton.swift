import SwiftUI

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
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
        let destination = appState.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if source.isEmpty {
            showError("Missing CSV File", "Select a CSV input file first.")
            return
        }
        if destination.isEmpty {
            showError("Missing Output File", "Set an Excel output file first.")
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
        let destDir = (destination as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: destDir) {
            showError("Invalid Path", "The destination directory does not exist.")
            return
        }

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
        let destURL = URL(fileURLWithPath: destination)

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
