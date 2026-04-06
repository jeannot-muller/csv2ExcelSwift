import SwiftUI

struct CSVPreviewView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if appState.cachedTotalRows > 0 {
                    Text("\(appState.cachedTotalRows) rows total")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)

            if appState.cachedPreviewRows.isEmpty {
                Text("No data to preview")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(Array(appState.cachedPreviewRows.enumerated()), id: \.offset) { rowIdx, row in
                            GridRow {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                    Text(cell)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(minWidth: 60, maxWidth: 180, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                }
                            }
                            .background(rowIdx == 0 && appState.hasHeaderRow ? Color.accentColor.opacity(0.08) : rowIdx % 2 == 0 ? Color.primary.opacity(0.03) : .clear)
                        }
                    }
                }
                .background(Color.primary.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))
                .padding(.horizontal, 20)
                .frame(maxHeight: 120)
            }
        }
        .padding(.bottom, 4)
        .onChange(of: appState.delimiter) { refreshPreview() }
        .onChange(of: appState.encoding) { refreshPreview() }
    }

    /// Re-parse preview when user manually changes encoding or delimiter.
    private func refreshPreview() {
        guard !appState.sourcePath.isEmpty else { return }

        let url = appState.resolveSourceURL()
        let accessing = url?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { url?.stopAccessingSecurityScopedResource() } }

        if let result = CSVParser.previewRows(
            fileAt: appState.sourcePath,
            encodingTag: appState.encoding,
            delimiter: appState.delimiter
        ) {
            appState.cachedPreviewRows = result.rows
            appState.cachedTotalRows = result.totalLines
        }
    }
}
