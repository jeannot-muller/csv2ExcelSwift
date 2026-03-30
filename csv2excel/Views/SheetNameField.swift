import SwiftUI

struct SheetNameField: View {
    @Environment(AppState.self) private var appState

    private let invalidChars = CharacterSet(charactersIn: "/\\?*:[]'")

    var body: some View {
        @Bindable var state = appState

        LabeledContent("Worksheet name") {
            TextField("Sheet1", text: $state.sheetName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .onChange(of: appState.sheetName) { _, newValue in
                    let filtered = String(newValue.unicodeScalars.filter { !invalidChars.contains($0) })
                    let truncated = String(filtered.prefix(31))
                    if truncated != newValue {
                        appState.sheetName = truncated
                    }
                }
        }
        .help("Max 31 characters. The characters / \\ ? * : [ ] ' are not allowed.")
    }
}
