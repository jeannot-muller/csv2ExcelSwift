import SwiftUI

struct DelimiterPicker: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        HStack {
            Text("DELIMITER")
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(.secondary)
            Picker("", selection: $state.delimiter) {
                Text("Semicolon").tag("semicolon")
                Text("Comma").tag("comma")
                Text("Tabulator").tag("tabulator")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)
            Spacer()
        }
    }
}
