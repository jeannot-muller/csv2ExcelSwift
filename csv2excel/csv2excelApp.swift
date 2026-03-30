import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppDelegate.reopenMainWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    static func reopenMainWindow() {
        for window in NSApp.windows where window.canBecomeMain && !window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // Fallback: URL scheme so SwiftUI's WindowGroup creates a new one
        if let url = URL(string: "csv2excel://open") {
            NSWorkspace.shared.open(url)
        }
    }
}

@main
struct csv2excelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(appState.isDarkTheme ? .dark : .light)
                .onOpenURL { _ in }
                .frame(minWidth: 580, minHeight: 480)
        }
        .defaultSize(width: 680, height: 580)
        .handlesExternalEvents(matching: ["csv2excel", "*"])
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

            CommandGroup(before: .windowList) {
                Button("Main Window") {
                    AppDelegate.reopenMainWindow()
                }
                .keyboardShortcut("0", modifiers: .command)
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
