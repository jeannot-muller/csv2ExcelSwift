import SwiftUI

struct NavBar: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var showImprint = false

    var body: some View {
        HStack {
            // Logo / app name
            Button {
                if let url = URL(string: "https://teccompanion.com") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tablecells")
                        .font(.title2)
                    Text("csv2excel")
                        .font(.headline)
                }
            }
            .buttonStyle(.plain)
            .help("Visit TECcompanion.com")

            Spacer()

            // Imprint
            Button {
                showImprint.toggle()
            } label: {
                Image(systemName: "tag")
            }
            .buttonStyle(.borderless)
            .help("Imprint")
            .popover(isPresented: $showImprint, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Imprint").font(.headline)
                    Divider()
                    Text("Dr. Jeannot Muller")
                    Text("c/o TECcompanion GmbH")
                    Text("Alexander-Pachmann-Str. 15")
                    Text("85716 Unterschleißheim")
                }
                .padding()
                .frame(width: 250)
            }

            // Theme toggle
            Button {
                appState.isDarkTheme.toggle()
                appState.save()
            } label: {
                Image(systemName: appState.isDarkTheme ? "sun.max" : "moon")
            }
            .buttonStyle(.borderless)
            .help("Switch Theme")

            // Help
            Button {
                openWindow(id: "help")
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Help")

            // Reset
            Button {
                appState.reset()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Reset Saved Data")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
