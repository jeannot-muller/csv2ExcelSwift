import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("csv2excel - Help")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                GroupBox("Getting Started") {
                    VStack(alignment: .leading, spacing: 8) {
                        helpItem(
                            "1. Select CSV File",
                            "Click Browse next to 'CSV file' to choose your input file (.csv or .txt)."
                        )
                        helpItem(
                            "2. Select Output File",
                            "Click Browse next to 'EXCEL file' to define where the .xlsx file will be saved."
                        )
                        helpItem(
                            "3. Choose Delimiter",
                            "Select the delimiter used in your CSV: comma, semicolon, or tabulator."
                        )
                        helpItem(
                            "4. Set Worksheet Name",
                            "Enter a name for the Excel worksheet (max 31 characters). Characters / \\ ? * : [ ] ' are not allowed."
                        )
                        helpItem(
                            "5. Add Metadata (Optional)",
                            "Expand 'EXCEL METADATA' to set document properties like title, author, company, etc."
                        )
                        helpItem(
                            "6. Convert",
                            "Click 'CONVERT .csv TO .xlsx' to perform the conversion."
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Smart Type Detection") {
                    Text("The converter automatically detects whether cell values are integers, decimal numbers, or text. Numeric values are stored as Excel numbers for proper sorting and calculation.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Keyboard Shortcuts") {
                    VStack(alignment: .leading, spacing: 4) {
                        shortcut("Reset all fields", "Trash icon in toolbar")
                        shortcut("Toggle theme", "System Appearance (automatic)")
                        shortcut("Open help", "? icon in toolbar")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }

    private func helpItem(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).fontWeight(.semibold)
            Text(description).foregroundStyle(.secondary)
        }
    }

    private func shortcut(_ action: String, _ keys: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(keys)
                .foregroundStyle(.secondary)
        }
    }
}
