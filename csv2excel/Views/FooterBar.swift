import SwiftUI

struct FooterBar: View {
    @Environment(AppState.self) private var appState

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var year: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    var body: some View {
        HStack {
            Text("Copyright \u{00A9} 2016-\(year) | MIT Licensed | TECcompanion GmbH, Europe | Release \(version)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if !appState.runTime.isEmpty {
                Text("Runtime last conversion: \(appState.runTime)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
