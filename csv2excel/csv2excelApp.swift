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
        .defaultSize(width: 680, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .newItem) {
                Button("Open CSV...") {
                    NotificationCenter.default.post(name: .openCSVFile, object: nil)
                }
                .keyboardShortcut("o")

                Button("Set Output File...") {
                    NotificationCenter.default.post(name: .setOutputFile, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(before: .toolbar) {
                Button("Convert") {
                    NotificationCenter.default.post(name: .triggerConvert, object: nil)
                }
                .keyboardShortcut("r")
            }

            CommandGroup(replacing: .help) {
                Button("csv2excel Help") {
                    NotificationCenter.default.post(name: .openHelp, object: nil)
                }
            }
        }

        Window("csv2excel Help", id: "help") {
            HelpView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 700, height: 500)
        .defaultLaunchBehavior(.suppressed)
    }
}

extension Notification.Name {
    static let openCSVFile = Notification.Name("openCSVFile")
    static let setOutputFile = Notification.Name("setOutputFile")
    static let triggerConvert = Notification.Name("triggerConvert")
    static let openHelp = Notification.Name("openHelp")
}
