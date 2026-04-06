import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Convert CSV files to Excel format with smart type detection and document metadata support.")
                    .foregroundStyle(.secondary)

                GroupBox("Quick Start") {
                    VStack(alignment: .leading, spacing: 10) {
                        step("1", "Open a CSV file", "Use File > Open CSV or \u{2318}O to select your input file. The delimiter is detected automatically.")
                        step("2", "Adjust options", "Pick the encoding, delimiter, and worksheet name. Optionally fill in document properties.")
                        step("3", "Convert", "Click Convert or press \u{2318}R. Choose where to save, then the status bar shows the conversion time.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Encoding Detection") {
                    Text("File encoding is detected automatically (UTF-8, Latin-1, Windows-1252, etc.). If special characters look wrong, select the correct encoding manually from the Options section — the preview updates instantly.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Smart Type Detection") {
                    Text("Cell values are automatically detected as integers, decimals, or text. Numbers are stored as Excel number types so sorting and formulas work correctly.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Keyboard Shortcuts") {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        shortcutRow("Open CSV file", "\u{2318}O")
                        shortcutRow("Convert", "\u{2318}R")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).foregroundStyle(.secondary).font(.callout)
            }
        }
    }

    private func shortcutRow(_ action: String, _ keys: String) -> some View {
        GridRow {
            Text(action)
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
