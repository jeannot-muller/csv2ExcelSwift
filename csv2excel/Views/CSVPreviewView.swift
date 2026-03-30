import SwiftUI

struct CSVPreviewView: View {
    @Environment(AppState.self) private var appState
    @State private var previewRows: [[String]] = []
    @State private var totalRows: Int = 0

    private let maxPreviewRows = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if totalRows > 0 {
                    Text("\(totalRows) rows total")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)

            if previewRows.isEmpty {
                Text("No data to preview")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(Array(previewRows.enumerated()), id: \.offset) { rowIdx, row in
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
                            .background(rowIdx == 0 ? Color.accentColor.opacity(0.08) : rowIdx % 2 == 0 ? Color.primary.opacity(0.03) : .clear)
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
        .onChange(of: appState.sourcePath) { loadPreview() }
        .onChange(of: appState.delimiter) { loadPreview() }
        .onChange(of: appState.encoding) { loadPreview() }
        .onAppear { loadPreview() }
    }

    private func loadPreview() {
        guard !appState.sourcePath.isEmpty else {
            previewRows = []
            totalRows = 0
            return
        }

        // Start security-scoped access if available
        let url = appState.resolveSourceURL()
        let accessing = url?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { url?.stopAccessingSecurityScopedResource() } }

        let delimChar: Character = switch appState.delimiter {
        case "semicolon": ";"
        case "tabulator": "\t"
        default: ","
        }

        guard let content = CSVParser.readString(fileAt: appState.sourcePath, encodingTag: appState.encoding) else {
            previewRows = []
            totalRows = 0
            return
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        totalRows = lines.count

        previewRows = lines.prefix(maxPreviewRows).map { line in
            parseLine(line, delimiter: delimChar)
        }
    }

    private func parseLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == delimiter && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
