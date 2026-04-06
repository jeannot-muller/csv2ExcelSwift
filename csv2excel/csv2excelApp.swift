import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Files passed via "Open With" / dock drop before the UI is ready (cold launch).
    @MainActor static var pendingFileURLs: [URL]?

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

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let validExtensions: Set<String> = ["csv", "txt", "tsv"]
        let urls = filenames
            .map { URL(fileURLWithPath: $0) }
            .filter { validExtensions.contains($0.pathExtension.lowercased()) }
        guard !urls.isEmpty else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }
        // Store for cold launch (onAppear picks these up if the view isn't ready yet)
        Self.pendingFileURLs = urls
        // Post notification for warm launch (view is already listening)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openFilesFromPicker, object: urls)
        }
        sender.reply(toOpenOrPrint: .success)
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
        .defaultSize(width: 680, height: 920)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: ["csv2excel", "file"])
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About csv2excel") {
                    NotificationCenter.default.post(name: .openAbout, object: nil)
                }
            }

            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .newItem) {
                Button("Open CSV...") {
                    NotificationCenter.default.post(name: .openCSVFile, object: nil)
                }
                .keyboardShortcut("o")

                Menu("Recent Files") {
                    if appState.recentFiles.isEmpty {
                        Text("No Recent Files")
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(appState.recentFiles) { recent in
                            Button(recent.name) {
                                if let url = recent.resolveURL() {
                                    let accessed = url.startAccessingSecurityScopedResource()
                                    // Notification handler runs synchronously on main,
                                    // creating a fresh bookmark from the URL. Safe to stop after.
                                    NotificationCenter.default.post(
                                        name: .openFileFromFinder,
                                        object: url
                                    )
                                    if accessed { url.stopAccessingSecurityScopedResource() }
                                }
                            }
                        }
                        Divider()
                        Button("Clear Recent Files") {
                            appState.recentFiles = []
                            appState.save()
                        }
                    }
                }
            }

            CommandGroup(before: .toolbar) {
                Button("Convert") {
                    NotificationCenter.default.post(name: .triggerConvert, object: nil)
                }
                .keyboardShortcut("r")
            }

            CommandGroup(before: .windowList) {
                Button("Standard Size") {
                    NotificationCenter.default.post(name: .resetWindowSize, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)

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

        Window("About csv2excel", id: "about") {
            AboutView()
                .preferredColorScheme(appState.isDarkTheme ? .dark : .light)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .handlesExternalEvents(matching: [])

        Window("csv2excel Help", id: "help") {
            HelpView()
                .environment(appState)
                .preferredColorScheme(appState.isDarkTheme ? .dark : .light)
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
    static let openFilesFromPicker = Notification.Name("openFilesFromPicker")
    static let resetWindowSize = Notification.Name("resetWindowSize")
    static let openAbout = Notification.Name("openAbout")
}
