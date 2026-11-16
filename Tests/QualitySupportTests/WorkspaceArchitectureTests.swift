import Foundation
import Testing

@testable import QualitySupport

@Suite("Workspace dependency policy")
struct WorkspaceArchitectureTests {
    @Test func forbiddenDependencyInADisposableSourceIsDetectedAndCorrectionPasses() throws {
        let fixture = try TemporaryDirectory(prefix: "architecture-fixture-")
        let source = fixture.url.appendingPathComponent("Injected.swift")
        try "import SwiftUI\nstruct Injected {}\n".write(
            to: source, atomically: true, encoding: .utf8)
        let findings = WorkspaceArchitecture.sourceViolations(
            try String(contentsOf: source, encoding: .utf8),
            path: "Sources/JarvisDomain/Injected.swift")
        #expect(findings == ["Sources/JarvisDomain/Injected.swift: forbidden import SwiftUI"])
        try "import Foundation\nstruct Corrected {}\n".write(
            to: source, atomically: true, encoding: .utf8)
        #expect(
            WorkspaceArchitecture.sourceViolations(
                try String(contentsOf: source, encoding: .utf8),
                path: "Sources/JarvisDomain/Injected.swift"
            ).isEmpty)
    }

    @Test func commentsAndLiteralsAreNotDependenciesButSplitAndAttributedImportsAre() {
        let harmless = #"""
            // import SwiftUI
            /* import AppKit /* nested */ */
            let description = "import JarvisWorkspace"
            let raw = #"import SQLite3"#
            import Foundation
            """#
        #expect(
            WorkspaceArchitecture.sourceViolations(
                harmless, path: "Sources/JarvisDomain/Models.swift"
            ).isEmpty)
        #expect(
            WorkspaceArchitecture.sourceViolations(
                "@_implementationOnly import\nSwiftUI", path: "Sources/JarvisDomain/Models.swift"
            ).count == 1)
        #expect(
            WorkspaceArchitecture.sourceViolations(
                "import struct AppKit.NSPoint", path: "Sources/JarvisDomain/Models.swift"
            ).count == 1)
    }

    @Test func domainEffectsAdapterUIAndDirectViewAccessAreRejected() {
        #expect(
            !WorkspaceArchitecture.sourceViolations(
                "let data = FileManager.default", path: "Sources/JarvisDomain/Rules.swift"
            ).isEmpty)
        #expect(
            !WorkspaceArchitecture.sourceViolations(
                "import Combine", path: "Sources/JarvisWorkspace/Reader.swift"
            ).isEmpty)
        #expect(
            !WorkspaceArchitecture.sourceViolations(
                "import JarvisWorkspace", path: "Sources/Jarvis/View.swift"
            ).isEmpty)
        #expect(
            !WorkspaceArchitecture.sourceViolations(
                "let reader = CodexReader()", path: "Sources/Jarvis/View.swift"
            ).isEmpty)
        #expect(
            WorkspaceArchitecture.sourceViolations(
                "import JarvisWorkspace\nlet reader = CodexReader()",
                path: "Sources/Jarvis/Main.swift"
            ).isEmpty)
    }

    @Test func actualTargetGraphMustPreserveTheAllowedEdgesAndRoots() throws {
        let positive = #"""
            {"targets":[
                {"name":"JarvisDomain","type":"regular","exclude":[],"dependencies":[]},
                {"name":"JarvisWorkspace","type":"regular","exclude":[],"dependencies":[{"byName":["JarvisDomain",null]}]},
                {"name":"Jarvis","type":"executable","exclude":[],"dependencies":[{"byName":["JarvisDomain",null]},{"byName":["JarvisWorkspace",null]}]}
            ]}
            """#
        #expect(try WorkspaceArchitecture.graphViolations(Data(positive.utf8)).isEmpty)
        let bad = positive.replacingOccurrences(
            of: #""type":"regular","exclude":[],"dependencies":[]"#,
            with: #""type":"regular","exclude":[],"dependencies":[{"byName":["Jarvis",null]}]"#)
        #expect(
            try WorkspaceArchitecture.graphViolations(Data(bad.utf8)) == [
                "JarvisDomain: dependencies must be []"
            ])
        let wrongRoot = positive.replacingOccurrences(
            of: #""name":"JarvisDomain""#,
            with: #""name":"JarvisDomain","path":"Sources/Jarvis""#)
        #expect(
            try WorkspaceArchitecture.graphViolations(Data(wrongRoot.utf8)) == [
                "JarvisDomain: unexpected source root"
            ])
    }
}
