import SwiftUI

@main
struct csv2excelApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(appState.isDarkTheme ? .dark : .light)
        }
        .defaultSize(width: 1024, height: 700)
        .windowResizability(.contentMinSize)

        Window("csv2excel - Help", id: "help") {
            HelpView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 1024, height: 768)
        .defaultLaunchBehavior(.suppressed)
    }
}
