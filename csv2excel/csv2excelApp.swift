import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var pendingFileURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent multiple instances
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        if runningApps.count > 1 {
            // Another instance is already running — activate it and quit this one
            if let other = runningApps.first(where: { $0 != NSRunningApplication.current }) {
                other.activate()
            }
            NSApp.terminate(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppDelegate.reopenMainWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor static func reopenMainWindow() {
        for window in NSApp.windows where window.canBecomeMain && !window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
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
                .onOpenURL { url in
                    handleFileOpen(url)
                }
                .frame(minWidth: 580, minHeight: 420)
        }
        .defaultSize(width: 680, height: 750)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: ["csv2excel", "file"])
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .newItem) {
                Button("Open CSV...") {
                    NotificationCenter.default.post(name: .openCSVFile, object: nil)
                }
                .keyboardShortcut("o")

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
        .handlesExternalEvents(matching: [])
    }

    private func handleFileOpen(_ url: URL) {
        // file:// URLs from "Open With", or csv2excel:// for window reopen
        guard url.isFileURL else { return }
        let ext = url.pathExtension.lowercased()
        guard ["csv", "txt", "tsv"].contains(ext) else { return }
        NotificationCenter.default.post(name: .openFileFromFinder, object: url)
    }
}

extension Notification.Name {
    static let openCSVFile = Notification.Name("openCSVFile")
    static let triggerConvert = Notification.Name("triggerConvert")
    static let openHelp = Notification.Name("openHelp")
    static let openFileFromFinder = Notification.Name("openFileFromFinder")
}
