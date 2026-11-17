import Foundation
import Testing

@testable import QualitySupport

@Suite("Command environment ownership")
struct CommandEnvironmentTests {
    @Test func ordinaryCommandsInheritPathButExplicitEnvironmentsReplaceIt() throws {
        let fixture = try TemporaryDirectory(prefix: "command-environment-")
        let inherited = fixture.url.appendingPathComponent("inherited.log")
        #expect(
            try Command("/usr/bin/printenv", ["PATH"], directory: fixture.url)
                .run(log: inherited, timeout: 5) == 0)
        #expect(
            try String(contentsOf: inherited, encoding: .utf8)
                .trimmingCharacters(in: .newlines) == ProcessInfo.processInfo.environment["PATH"])
        let explicit = Command(
            "/usr/bin/printenv", ["JARVIS_SYNTHETIC"], directory: fixture.url,
            environment: ["JARVIS_SYNTHETIC": "fixture"])
        let isolated = fixture.url.appendingPathComponent("isolated.log")
        #expect(try explicit.run(log: isolated, timeout: 5) == 0)
        #expect(try String(contentsOf: isolated, encoding: .utf8) == "fixture\n")
        let absent = Command(
            "/usr/bin/printenv", ["PATH"], directory: fixture.url,
            environment: ["JARVIS_SYNTHETIC": "fixture"])
        #expect(try absent.run(log: isolated, timeout: 5) == 1)
        #expect(try Data(contentsOf: isolated).isEmpty)
    }
}
