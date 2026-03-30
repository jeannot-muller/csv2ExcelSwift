import SwiftUI

enum ToastStyle {
    case success, warning, error
}

struct ToastMessage: Equatable {
    let style: ToastStyle
    let title: String
    let detail: String

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.title == rhs.title && lhs.detail == rhs.detail
    }
}

struct ConvertButton: View {
    @Environment(AppState.self) private var appState
    @State private var isConverting = false
    @State private var toast: ToastMessage?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button {
                    convert()
                } label: {
                    Label("CONVERT .csv TO .xlsx", systemImage: "gearshape")
                        .frame(width: 230)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isConverting)

                if isConverting {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            // Toast overlay
            if let toast {
                HStack(spacing: 8) {
                    Image(systemName: toastIcon(toast.style))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.title).font(.headline)
                        Text(toast.detail).font(.caption)
                    }
                }
                .padding(10)
                .background(toastColor(toast.style).opacity(0.15))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(toastColor(toast.style), lineWidth: 1)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: toast)
    }

    private func convert() {
        let source = appState.sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = appState.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if source.isEmpty {
            showToast(.warning, title: "Missing CSV File", detail: "Please select a CSV input file before converting.")
            return
        }
        if destination.isEmpty {
            showToast(.warning, title: "Missing Excel File", detail: "Please specify an Excel output file before converting.")
            return
        }
        if appState.sheetName.isEmpty {
            showToast(.error, title: "Invalid Sheet Name", detail: "Worksheet name cannot be blank.")
            return
        }
        if !FileManager.default.fileExists(atPath: source) {
            showToast(.error, title: "Source Missing", detail: "Source file missing!")
            return
        }
        let destDir = (destination as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: destDir) {
            showToast(.error, title: "Destination Missing", detail: "Destination path missing!")
            return
        }

        isConverting = true

        // Capture values on the main actor before dispatching
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

        // Resolve security-scoped bookmarks for sandbox access
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
                    showToast(.success, title: "Success", detail: "File converted successfully!")
                }
            } catch {
                await MainActor.run {
                    appState.runTime = "ERR"
                    appState.save()
                    isConverting = false
                    showToast(.error, title: "Something went wrong", detail: error.localizedDescription)
                }
            }
        }
    }

    private func showToast(_ style: ToastStyle, title: String, detail: String) {
        toast = ToastMessage(style: style, title: title, detail: detail)
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                toast = nil
            }
        }
    }

    private func toastIcon(_ style: ToastStyle) -> String {
        switch style {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.circle.fill"
        }
    }

    private func toastColor(_ style: ToastStyle) -> Color {
        switch style {
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
