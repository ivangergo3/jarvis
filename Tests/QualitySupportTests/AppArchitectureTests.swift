import Foundation
import Testing

@testable import QualitySupport

@Suite("Native app dependency policy")
struct AppArchitectureTests {
    private let shared = "Sources/Jarvis/Shared/Contracts.swift"
    private let application = "Sources/Jarvis/Application/State.swift"
    private let integration = "Sources/Jarvis/Integrations/Store.swift"
    private let view = "Sources/Jarvis/Presentation/Views/Screen.swift"

    @Test func reverseReferencesAreRejectedEvenWithoutImports() {
        let findings = AppArchitecture.violations(sources: [
            shared: "struct Contract { let state: ScreenState }",
            application: "class ScreenState { let store: DiskStore }",
            integration: "actor DiskStore { let screen: Screen }",
            view: "struct Screen {}",
        ])
        #expect(
            findings
                == [
                    "\(application): forbidden Integrations reference DiskStore",
                    "\(integration): forbidden Presentation reference Screen",
                    "\(shared): forbidden Application reference ScreenState",
                ].sorted())
        #expect(
            AppArchitecture.violations(sources: [
                shared: "protocol Storage {}",
                application: "class ScreenState { let store: any Storage }",
                integration: "actor DiskStore: Storage {}",
                view: "struct Screen { let state: ScreenState }",
            ]).isEmpty)
    }

    @Test func importsAndPrivilegedEffectsCannotHideBehindFoundation() {
        #expect(
            AppArchitecture.violations(sources: [
                shared: "import Foundation\nlet file = try Data(contentsOf: url)",
                application: "@preconcurrency import\nAppKit",
                view: "import struct ImageIO.Image\nlet panel = NSOpenPanel()",
            ])
                == [
                    "\(application): forbidden import AppKit",
                    "\(view): forbidden effect NSOpenPanel",
                    "\(view): forbidden import ImageIO",
                    "\(shared): forbidden effect contentsOf",
                ].sorted())
    }

    @Test func nativeBridgesAreInjectedAndCannotLaunchOtherAppsDirectly() {
        let definitions = "class LocalVoice {}\nclass DesktopActions {}"
        #expect(
            AppArchitecture.violations(sources: [
                integration: definitions,
                view: "struct Screen { let voice: LocalVoice; let actions: DesktopActions }",
                "Sources/Jarvis/Main.swift": "let voice = LocalVoice()",
            ]).isEmpty)
        #expect(
            AppArchitecture.violations(sources: [
                integration: definitions,
                view: "let voice = LocalVoice(); NSWorkspace.shared.open(url)",
            ]) == [
                "\(view): external launches belong in Integrations",
                "\(view): inject LocalVoice from composition",
            ])
    }

    @Test func newSourceFilesMustHaveAnExplicitLayer() {
        for path in [
            "Sources/Jarvis/Loose.swift", "Sources/Jarvis/Utilities/File.swift",
            "Sources/Jarvis/Presentation/Loose.swift",
        ] {
            #expect(
                AppArchitecture.violations(sources: [path: "struct Value {}"])
                    == ["\(path): uncategorized app source"])
        }
    }

    @Test func nativeExceptionsDoNotPermitFileReadsOrPreferencesInOtherViews() {
        #expect(
            AppArchitecture.violations(sources: [
                view: "let image = NSImage(contentsOf: url); let prefs = UserDefaults.standard"
            ]) == [
                "\(view): forbidden effect UserDefaults", "\(view): forbidden effect contentsOf",
            ])
        #expect(
            AppArchitecture.violations(sources: [
                "Sources/Jarvis/Presentation/Platform/HUDAnimations.swift":
                    "let image = NSImage(contentsOf: url)",
                "Sources/Jarvis/Application/DashboardState.swift": "let prefs: UserDefaults?",
            ]).isEmpty)
    }

    @Test func commentsLiteralsAndNestedTypeNamesDoNotInventCrossLayerReferences() {
        #expect(
            AppArchitecture.violations(sources: [
                integration: "actor DiskStore { enum Failure {}; let error: Failure }",
                application: #"""
                import Foundation
                /* import AppKit /* nested */ */
                // DiskStore()
                let example = #"FileManager.default and DiskStore()"#
                enum Failure {}
                """#,
            ]).isEmpty)
    }

    @Test func missingAndEmptySourceRootsCannotPassTheGate() throws {
        let fixture = try TemporaryDirectory(prefix: "app-architecture-")
        #expect(throws: QualityFailure.self) {
            try AppArchitecture.check(root: fixture.url, output: fixture.url)
        }
        try FileManager.default.createDirectory(
            at: fixture.url.appendingPathComponent("Sources/Jarvis"),
            withIntermediateDirectories: true)
        #expect(throws: QualityFailure.self) {
            try AppArchitecture.check(root: fixture.url, output: fixture.url)
        }
    }
}
