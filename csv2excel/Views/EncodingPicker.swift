import SwiftUI

struct EncodingPicker: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Picker("Encoding", selection: $state.encoding) {
            ForEach(CSVParser.supportedEncodings, id: \.tag) { enc in
                Text(enc.name).tag(enc.tag)
            }
        }
    }
}
