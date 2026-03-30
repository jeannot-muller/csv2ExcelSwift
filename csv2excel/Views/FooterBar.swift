import SwiftUI

struct FooterBar: View {
    @Environment(AppState.self) private var appState

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        HStack {
            Text("v\(version)")
                .font(.caption2)
                .foregroundStyle(.quaternary)

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
