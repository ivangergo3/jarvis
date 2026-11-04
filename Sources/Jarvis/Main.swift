import AppKit
import SwiftUI

@main enum JarvisMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--self-test") {
            fputs("Tests now run separately: use swift test from the project folder.\n", stderr)
            exit(64)
        }
        if CommandLine.arguments.contains("--diagnose") {
            Task {
                do {
                    let snapshot = try await CodexReader().read()
                    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
                    print(String(data: try encoder.encode(snapshot), encoding: .utf8)!)
                    exit(0)
                } catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
            }
            dispatchMain()
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        // AppKit owns the main run loop; do not hold a Swift concurrency job across app.run().
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Jarvis", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Jarvis", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let viewItem = NSMenuItem(); viewItem.title = "View"; menu.addItem(viewItem)
        let viewMenu = NSMenu(); viewItem.submenu = viewMenu
        let fullscreen = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullscreen.keyEquivalentModifierMask = [.control, .command]; viewMenu.addItem(fullscreen)
        NSApp.mainMenu = menu
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1500, height: 940), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Jarvis — Mission Control"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.025, green: 0.045, blue: 0.065, alpha: 1)
        window.minSize = NSSize(width: 1180, height: 760)
        window.contentView = NSHostingView(rootView: Dashboard())
        window.collectionBehavior = [.fullScreenPrimary]
        window.setFrameAutosaveName("JarvisMissionControl")
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil); return true
    }
}
