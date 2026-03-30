import SwiftUI

struct SheetNameField: View {
    @Environment(AppState.self) private var appState

    private let invalidChars = CharacterSet(charactersIn: "/\\?*:[]'")

    var body: some View {
        @Bindable var state = appState

        HStack {
            Text("WORKSHEET")
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(.secondary)
            TextField(
                "Max 31 characters; / \\ ? * : [ ] ' are disallowed",
                text: $state.sheetName
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 400)
            .onChange(of: appState.sheetName) { _, newValue in
                let filtered = String(newValue.unicodeScalars.filter { !invalidChars.contains($0) })
                let truncated = String(filtered.prefix(31))
                if truncated != newValue {
                    appState.sheetName = truncated
                }
            }
            Spacer()
        }
    }
}
