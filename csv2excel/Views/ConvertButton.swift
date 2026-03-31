import SwiftUI
import AppKit

struct ConvertButton: View {
    @Environment(AppState.self) private var appState
    @State private var isConverting = false
    @State private var conversionTask: Task<Void, Never>?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var alertIsError = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if appState.isBatchMode {
                    convertBatch()
                } else {
                    convertSingle()
                }
            } label: {
                Label(appState.isBatchMode ? "Convert All" : "Convert", systemImage: "arrow.triangle.2.circlepath")
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
                Button("Cancel") {
                    conversionTask?.cancel()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.callout)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .onReceive(NotificationCenter.default.publisher(for: .triggerConvert)) { _ in
            if appState.isBatchMode {
                convertBatch()
            } else {
                convertSingle()
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Single File Conversion

    private func convertSingle() {
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

        // Start security scope early so fileExists check works in sandbox
        let sourceURL = appState.resolveSourceURL()
        let sourceAccess = sourceURL?.startAccessingSecurityScopedResource() ?? false
        defer { if sourceAccess { sourceURL?.stopAccessingSecurityScopedResource() } }

        if !FileManager.default.fileExists(atPath: source) {
            showError("File Not Found", "The source CSV file no longer exists at the specified path.")
            return
        }

        let suggestedName = ((source as NSString).lastPathComponent as NSString).deletingPathExtension + ".xlsx"
        let suggestedDir = (source as NSString).deletingLastPathComponent

        // Always show Save panel for sandbox compliance.
        // "Save next to source" pre-fills the panel so user just hits Enter.
        let panel = NSSavePanel()
        panel.title = "Save Excel File"
        panel.nameFieldStringValue = suggestedName
        panel.directoryURL = URL(fileURLWithPath: suggestedDir)
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        if appState.saveToSameLocation {
            panel.message = "Save next to source file — press Return to confirm."
        }
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
        let encodingTag = appState.encoding
        let sheetName = appState.sheetName
        let properties = captureProperties()

        // Re-resolve bookmarks for the background task's own scope
        let taskSourceURL = appState.resolveSourceURL()
        let taskDestURL = appState.resolveDestinationURL()
        let taskSourceAccess = taskSourceURL?.startAccessingSecurityScopedResource() ?? false
        let taskDestAccess = taskDestURL?.startAccessingSecurityScopedResource() ?? false

        conversionTask = Task.detached(priority: .userInitiated) {
            defer {
                if taskSourceAccess { taskSourceURL?.stopAccessingSecurityScopedResource() }
                if taskDestAccess { taskDestURL?.stopAccessingSecurityScopedResource() }
            }
            let start = ContinuousClock.now
            do {
                var session = try XLSXWriter.Session.open(
                    sheetName: sheetName,
                    properties: properties,
                    to: destURL
                )
                try CSVParser.parseStreaming(
                    fileAt: source,
                    delimiter: delimiter,
                    encodingTag: encodingTag
                ) { row in
                    session.addRow(row)
                }
                try session.finish()

                let duration = formatDuration(from: start)

                await MainActor.run {
                    appState.runTime = duration
                    appState.save()
                    isConverting = false
                    showSuccess("Conversion Complete", "File created successfully in \(duration).")
                }
            } catch is CancellationError {
                try? FileManager.default.removeItem(at: destURL)
                await MainActor.run {
                    isConverting = false
                    showError("Cancelled", "Conversion was cancelled.")
                }
            } catch {
                try? FileManager.default.removeItem(at: destURL)
                await MainActor.run {
                    appState.runTime = "ERR"
                    appState.save()
                    isConverting = false
                    showError("Conversion Failed", error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Batch Conversion

    private func convertBatch() {
        guard !isConverting else { return }
        guard !appState.batchFiles.isEmpty else {
            showError("No Files", "No files selected for batch conversion.")
            return
        }
        if appState.sheetName.isEmpty {
            showError("Invalid Sheet Name", "Worksheet name cannot be blank.")
            return
        }

        // Always require an output directory for sandbox compliance.
        // Pre-select first file's directory when "save next to source" is on.
        let panel = NSOpenPanel()
        panel.title = "Choose Output Directory for Batch"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if appState.saveToSameLocation, let first = appState.batchFiles.first {
            panel.directoryURL = first.url.deletingLastPathComponent()
            panel.message = "Select the output directory — press Return to confirm."
        }
        guard panel.runModal() == .OK, let outputDirURL = panel.url else { return }
        isConverting = true

        // Reset all statuses to pending
        for i in appState.batchFiles.indices {
            appState.batchFiles[i].status = .pending
        }

        let encodingTag = appState.encoding
        let sheetName = appState.sheetName
        let properties = captureProperties()
        let files = appState.batchFiles

        // Resolve bookmarks and start security-scoped access for each file
        // before entering the background task.
        var fileAccessTokens: [(url: URL, accessed: Bool)] = []
        for file in files {
            let resolvedURL = file.resolveURL() ?? file.url
            let accessed = resolvedURL.startAccessingSecurityScopedResource()
            fileAccessTokens.append((resolvedURL, accessed))
        }

        conversionTask = Task.detached(priority: .userInitiated) {
            defer {
                for (url, accessed) in fileAccessTokens {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
            }

            let overallStart = ContinuousClock.now
            var successCount = 0
            var errorCount = 0

            for (index, file) in files.enumerated() {
                try? Task.checkCancellation()

                await MainActor.run {
                    if index < appState.batchFiles.count {
                        appState.batchFiles[index].status = .converting
                    }
                }

                // Use the resolved, security-scoped URL for file access
                let scopedPath = fileAccessTokens[index].url.path(percentEncoded: false)
                let destURL = outputDirURL.appendingPathComponent(
                    file.url.deletingPathExtension().lastPathComponent + ".xlsx"
                )

                let fileStart = ContinuousClock.now
                do {
                    let delimiter = CSVParser.detectDelimiter(fileAt: scopedPath, encodingTag: encodingTag)
                    var session = try XLSXWriter.Session.open(
                        sheetName: sheetName,
                        properties: properties,
                        to: destURL
                    )
                    try CSVParser.parseStreaming(
                        fileAt: scopedPath,
                        delimiter: delimiter,
                        encodingTag: encodingTag
                    ) { row in
                        session.addRow(row)
                    }
                    try session.finish()

                    let duration = formatDuration(from: fileStart)
                    successCount += 1

                    await MainActor.run {
                        if index < appState.batchFiles.count {
                            appState.batchFiles[index].status = .done(duration: duration)
                        }
                    }
                } catch is CancellationError {
                    try? FileManager.default.removeItem(at: destURL)
                    await MainActor.run {
                        for i in index..<appState.batchFiles.count {
                            if case .converting = appState.batchFiles[i].status {
                                appState.batchFiles[i].status = .error(message: "Cancelled")
                            } else if case .pending = appState.batchFiles[i].status {
                                appState.batchFiles[i].status = .error(message: "Cancelled")
                            }
                        }
                        isConverting = false
                        showError("Cancelled", "Batch conversion was cancelled after \(successCount) file(s).")
                    }
                    return
                } catch {
                    try? FileManager.default.removeItem(at: destURL)
                    errorCount += 1
                    let msg = error.localizedDescription
                    await MainActor.run {
                        if index < appState.batchFiles.count {
                            appState.batchFiles[index].status = .error(message: msg)
                        }
                    }
                }
            }

            let totalDuration = formatDuration(from: overallStart)
            await MainActor.run {
                appState.runTime = totalDuration
                appState.save()
                isConverting = false
                if errorCount == 0 {
                    showSuccess("Batch Complete", "\(successCount) file(s) converted in \(totalDuration).")
                } else {
                    showError("Batch Complete", "\(successCount) succeeded, \(errorCount) failed. Total: \(totalDuration).")
                }
            }
        }
    }

    // MARK: - Helpers

    private func captureProperties() -> XLSXDocProperties {
        XLSXDocProperties(
            title: appState.xlsxTitle,
            subject: appState.xlsxSubject,
            author: appState.xlsxAuthor,
            manager: appState.xlsxManager,
            company: appState.xlsxCompany,
            category: appState.xlsxCategory,
            keywords: appState.xlsxKeywords,
            comment: appState.xlsxComment
        )
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

private func formatDuration(from start: ContinuousClock.Instant) -> String {
    let elapsed = start.duration(to: .now)
    let seconds = Double(elapsed.components.attoseconds) / 1e18 + Double(elapsed.components.seconds)
    return String(format: "%.4f s", seconds)
}
