import SwiftUI

struct DelimiterPicker: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Picker("Delimiter", selection: $state.delimiter) {
            Text("Comma (,)").tag("comma")
            Text("Semicolon (;)").tag("semicolon")
            Text("Tab (\u{21E5})").tag("tabulator")
        }
        .pickerStyle(.segmented)
    }
}
