import AppKit
import JarvisDomain
import JarvisWorkspace
import SwiftUI

@main enum JarvisMain {
    @MainActor static func main() {
        let enteredMain = ProcessInfo.processInfo.systemUptime
        let arguments = CommandLine.arguments
        let launch: WorkspaceLaunch
        let verification: UIVerification?
        do {
            verification = try UIVerification.parse(arguments)
            if Bundle.main.bundleIdentifier == "dev.jarvis.verification", verification == nil {
                throw VerificationFailure(
                    message: "The verification app requires synthetic launch arguments.")
            }
            launch = try WorkspaceLaunch.resolve(
                arguments: arguments,
                bundleIdentifier: Bundle.main.bundleIdentifier,
                fixtureDirectory: Bundle.main.object(
                    forInfoDictionaryKey: "JarvisWorkspaceFixtureDirectory") as? String)
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(64)
        }
        let source: any WorkspaceSource
        let fixtureClock =
            (Bundle.main.object(forInfoDictionaryKey: "JarvisPerformanceClock") as? NSNumber)
            .map { Date(timeIntervalSince1970: $0.doubleValue) }
        if let verification {
            source = VerificationFleetSource(verification.scenario)
        } else {
            switch launch {
            case .live: source = CodexReader()
            case .fixture(let home):
                source = CodexReader(home: home, now: { fixtureClock ?? Date() })
            }
        }
        if arguments.contains("--performance-baseline") {
            guard verification == nil, case .fixture(let home) = launch,
                let revision = arguments.first(where: { $0.hasPrefix("--revision=") })
            else { exit(64) }
            Task {
                do {
                    try await PerformanceWorkloads.run(
                        home: home,
                        output: home.deletingLastPathComponent().appendingPathComponent(
                            "performance-workloads.json"),
                        revision: String(revision.dropFirst("--revision=".count)),
                        makeSource: { CodexReader(home: home, now: { fixtureClock ?? Date() }) })
                    exit(0)
                } catch {
                    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                    exit(1)
                }
            }
            dispatchMain()
        }
        if CommandLine.arguments.contains("--self-test") {
            fputs("Tests now run separately: use swift test from the project folder.\n", stderr)
            exit(64)
        }
        if CommandLine.arguments.contains("--diagnose") {
            Task {
                do {
                    let snapshot = try await source.read()
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dateEncodingStrategy = .iso8601
                    print(String(data: try encoder.encode(snapshot), encoding: .utf8)!)
                    exit(0)
                } catch {
                    fputs("FAIL: \(error.localizedDescription)\n", stderr)
                    exit(1)
                }
            }
            dispatchMain()
        }
        let app = NSApplication.shared
        let output = Bundle.main.object(forInfoDictionaryKey: "JarvisPerformanceOutput") as? String
        #if DEBUG
            if output != nil { exit(64) }
        #endif
        guard output == nil || (launch.isFixture && verification == nil) else { exit(64) }
        let performance: PerformanceSession?
        do {
            if let output, case .fixture(let home) = launch {
                let fixture = try JSONDecoder().decode(
                    [String: Int].self,
                    from: Data(contentsOf: home.appendingPathComponent("performance-fixture.json")))
                performance = PerformanceSession(
                    enteredMain: enteredMain, output: URL(fileURLWithPath: output),
                    fixture: fixture,
                    manual: Bundle.main.object(forInfoDictionaryKey: "JarvisPerformanceManual")
                        as? Bool == true)
            } else {
                performance = nil
            }
        } catch {
            FileHandle.standardError.write(Data("Invalid performance fixture metadata.\n".utf8))
            exit(64)
        }
        let delegate = AppDelegate(
            source: source, workspaceFixture: launch.isFixture, verification: verification,
            performance: performance)
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        // AppKit owns the main run loop; do not hold a Swift concurrency job across app.run().
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let companion: CompanionModel
    private let workspaceFixture: Bool
    private let voice: LocalVoice
    private let store: FleetStore
    private let ui: DashboardState
    private let imagePreview: ImagePreviewPresentation
    private let desktopActions: DesktopActions
    private let verification: UIVerification?
    private let performance: PerformanceSession?
    private let evidence = VerificationEvidence()
    private let windowControls = WindowControls()
    private var verificationLifetime: Task<Void, Never>?
    init(
        source: any WorkspaceSource, workspaceFixture: Bool = false,
        verification: UIVerification? = nil, performance: PerformanceSession? = nil
    ) {
        store = FleetStore(source: source)
        self.workspaceFixture = workspaceFixture
        self.verification = verification
        self.performance = performance
        let externalActionsAllowed = verification == nil && !workspaceFixture
        desktopActions = DesktopActions(allowed: externalActionsAllowed)
        let previewLoader = AttachmentPreviewLoader()
        imagePreview = ImagePreviewPresentation { file, pixels in
            guard externalActionsAllowed else { return nil }
            return await previewLoader.load(file, pixels: pixels)
        }
        if verification != nil {
            let evidence = evidence
            let connection = VerificationConnection { thread, text in
                await evidence.record(thread: thread, text: text)
            }
            companion = CompanionModel(allowsExternalActions: false, makeConnection: { connection })
            voice = LocalVoice(preferences: nil, allowsAudio: false)
            ui = DashboardState(preferences: nil)
            ui.motion = false
            ui.refreshInterval = .fast
        } else {
            companion =
                workspaceFixture
                ? CompanionModel(
                    allowsExternalActions: false,
                    makeConnection: { DisabledWorkspaceFixtureConnection() })
                : CompanionModel(imageStore: ComposerImageStore()) {
                    CodexProcessConnection(executable: CodexExecutable.locate())
                }
            voice = LocalVoice()
            ui = performance?.dashboard ?? DashboardState()
        }
        super.init()
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        windowControls.applicationActive = true
    }
    func applicationDidResignActive(_ notification: Notification) {
        windowControls.applicationActive = false
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "About Jarvis",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Jarvis", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        let editItem = NSMenuItem()
        editItem.title = "Edit"
        menu.addItem(editItem)
        let editMenu = NSMenu()
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(
            withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let viewItem = NSMenuItem()
        viewItem.title = "View"
        menu.addItem(viewItem)
        let viewMenu = NSMenu()
        viewItem.submenu = viewMenu
        let fullscreen = NSMenuItem(
            title: "Toggle Full Screen", action: #selector(WindowControls.toggleFullScreen(_:)),
            keyEquivalent: "f")
        fullscreen.target = windowControls
        fullscreen.keyEquivalentModifierMask = [.control, .command]
        viewMenu.addItem(fullscreen)
        NSApp.mainMenu = menu
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1500, height: 940),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Jarvis — Mission Control"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.025, green: 0.045, blue: 0.065, alpha: 1)
        window.minSize = NSSize(width: 1180, height: 760)
        windowControls.attach(to: window)
        let content = VStack(spacing: 0) {
            if let verification {
                VerificationBanner(configuration: verification, evidence: evidence)
            }
            Dashboard(
                windowControls: windowControls, companion: companion, voice: voice,
                store: store, ui: ui, imagePreview: imagePreview,
                workspaceFixture: workspaceFixture)
        }.environmentObject(desktopActions)
            .overlay(alignment: .top) {
                if let performance {
                    PerformanceStatusView(
                        progress: performance.progress, manual: performance.manual
                    ) {
                        performance.startManual()
                    }
                }
            }
        window.contentView =
            performance == nil
            ? NSHostingView(rootView: content) : PerformanceHostingView(rootView: content)
        window.collectionBehavior = [.fullScreenPrimary]
        if verification == nil { window.setFrameAutosaveName("JarvisMissionControl") }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        performance?.attach(window: window, store: store, companion: companion)
        if verification != nil {
            verificationLifetime = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(120)) } catch { return }
                NSApplication.shared.terminate(nil)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        performance?.stop()
        voice.cancel()
        voice.stopAudio()
        if verification != nil { return .terminateNow }
        Task {
            await companion.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool)
        -> Bool
    {
        window?.makeKeyAndOrderFront(nil)
        return true
    }
}

/// Explicit fixture launches never start Codex or send a real conversation request.
private actor DisabledWorkspaceFixtureConnection: CodexConnection {
    func request(_ method: String, params: WireValue) throws -> WireValue {
        throw ConnectionFailure.unavailable
    }
    func notify(_ method: String) {}
    func respond(to id: WireValue, result: WireValue) {}
    func reject(_ id: WireValue, message: String) {}
    func events() -> AsyncStream<CodexEvent> { AsyncStream { $0.finish() } }
    func close() {}
}
