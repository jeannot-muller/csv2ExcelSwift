import SwiftUI

struct DecimalStylePicker: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        Picker("Number format", selection: $state.decimalStyle) {
            Text("Auto-Detect").tag("auto")
            Text("Dot (1,234.56)").tag("dot")
            Text("Comma (1.234,56)").tag("comma")
        }
        .onChange(of: appState.decimalStyle) { appState.save() }
    }
}
