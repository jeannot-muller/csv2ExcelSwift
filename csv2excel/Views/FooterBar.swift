import SwiftUI

struct FooterBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack {
            Spacer()

            if !appState.runTime.isEmpty {
                Text("Last conversion: \(appState.runTime)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
