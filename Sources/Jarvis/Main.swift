import AppKit
import SwiftUI

@main enum JarvisMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--self-test") || CommandLine.arguments.contains("--diagnose") {
            Task {
                do {
                    if CommandLine.arguments.contains("--self-test") {
                        try await SelfTests.run()
                        print("PASS: lifecycle parsing, task filtering, read-only database and live team integration")
                    } else {
                        let snapshot = try await CodexReader().read()
                        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
                        print(String(data: try encoder.encode(snapshot), encoding: .utf8)!)
                    }
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

enum SelfTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw ReaderFailure(message: message) }
    }
    static func run() async throws {
        var observation = LogObservation()
        observation.consume(#"{"type":"event_msg","timestamp":"2026-11-04T09:00:00Z","payload":{"type":"task_started"}}"#)
        try require(observation.status == .working, "Start must mean in progress")
        observation.consume(#"{"type":"response_item","timestamp":"2026-11-04T09:00:01Z","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Build a dashboard"}]}}"#)
        try require(observation.task == "Build a dashboard", "User request should be captured")
        observation.consume(#"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"text":"<send_user_message_question_reply>yes</send_user_message_question_reply>"}]}}"#)
        try require(observation.task == "Build a dashboard", "Approval replies must not replace task")
        observation.consume(#"{"type":"event_msg","payload":{"type":"task_complete"}}"#)
        try require(observation.status == .standby, "Completed turn must not remain active")
        observation.consume(#"{"type":"event_msg","payload":{"type":"task_started"}}"#)
        observation.consume(#"{"type":"event_msg","payload":{"type":"turn_aborted"}}"#)
        try require(observation.status == .interrupted, "Interrupted turn must not remain active")
        observation.consume("{truncated")
        try require(observation.status == .interrupted, "Partial JSON must be ignored safely")
        try require(LogObservation.cleanTask("<heartbeat>anything") == nil, "Ignore automated heartbeats")
        try require(LogObservation.cleanTask("<realtime_delegation><input>Create a calendar</input></realtime_delegation>") == "Create a calendar", "Extract voice request")
        for count in [4, 7, 20] {
            for viewport in [CGSize(width: 660, height: 460), CGSize(width: 1200, height: 820)] {
                let graph = TeamGraphLayout(count: count, viewport: viewport)
                let boxes = graph.nodes.map { CGRect(x: $0.x - graph.cardWidth / 2, y: $0.y - 90, width: graph.cardWidth, height: 180).insetBy(dx: 1, dy: 1) }
                for (target, connection) in graph.connections.enumerated() {
                    let node = graph.nodes[target]
                    let edge = node.x + (node.x < graph.center.x ? graph.cardWidth / 2 : -graph.cardWidth / 2)
                    try require(connection.destination == CGPoint(x: edge, y: node.y), "Each connector must end on its own card edge")
                    for step in 0...500 {
                        let point = connection.point(at: Double(step) / 500)
                        try require(!boxes.enumerated().contains { $0.offset != target && $0.element.contains(point) }, "Connector must not pass through another box")
                    }
                    try require(connection.point(at: 1) == connection.destination, "Travelling pulse must reach its destination")
                }
            }
        }
        let reader = CodexReader()
        let first = try await reader.read()
        let names = Set(first.projects.filter { !$0.isUnassigned }.map(\.name))
        try require(Set(["money", "proto-visualiser", "where-to-dance", "grpc-tests"]).isSubset(of: names), "Discover actual Codex projects")
        guard let money = first.projects.first(where: { $0.name == "money" }) else { throw ReaderFailure(message: "Missing money project") }
        let moneyTeam = first.missions.filter { $0.projectID == money.id }
        try require(Set(["Xiaomi monitor", "Coding", "Marketing", "LinkedIn"]).isSubset(of: Set(moneyTeam.map(\.name))), "Preserve the original four chats in the correct project")
        try require(first.missions.allSatisfy { mission in first.projects.contains { $0.id == mission.projectID } }, "Every chat must belong to a selectable project or Unassigned")
        try require(Set(first.missions.map(\.id)).count == first.missions.count, "Do not duplicate chats across projects")
        let catalog = ProjectMembership(projects: [WorkspaceProject(id: "a", name: "outer", roots: ["/work/app"]), WorkspaceProject(id: "b", name: "inner", roots: ["/work/app/nested"])], aliases: ["legacy": "a"], assignments: ["moved": "legacy"], unassigned: ["loose"])
        try require(catalog.projectID(threadID: "x", explicitID: nil, cwd: "/work/app/nested/src") == "b", "Use the most specific project root")
        try require(catalog.projectID(threadID: "x", explicitID: nil, cwd: "/work/apple") == "unassigned", "Do not match sibling folders by text prefix")
        try require(catalog.projectID(threadID: "moved", explicitID: nil, cwd: "/elsewhere") == "a", "Respect migrated explicit project assignments")
        try require(catalog.projectID(threadID: "loose", explicitID: "a", cwd: "/work/app") == "unassigned", "Respect explicitly projectless chats")
        try require(catalog.projectID(threadID: "x", explicitID: "b", cwd: "/work/app") == "b", "Explicit project must take precedence over cwd")
        let second = try await reader.read()
        try require(Set(second.missions.map(\.id)) == Set(first.missions.map(\.id)), "Repeated polling should preserve stable identities even when activity changes their order")
        try require(second.missions.allSatisfy { !$0.task.isEmpty }, "Tasks must have readable text or an explicit unavailable state")
    }
}
