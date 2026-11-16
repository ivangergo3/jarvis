import Foundation
import Testing
import QualitySupport

@testable import Jarvis

@Suite("App Server subprocess boundary")
struct ProcessConnectionTests {
    @Test func literalTextRoundTripsWithoutShellExecutionAndCloseReleasesPendingCalls() async throws
    {
        let fixture = try SessionFixture()
        let executable = fixture.home.appendingPathComponent("fake-codex")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/EchoServer.swift")
        let compileLog = fixture.home.appendingPathComponent("compile.log")
        let status = try Command("/usr/bin/xcrun", ["swiftc", source.path, "-o", executable.path],
                                 directory: fixture.home).run(log: compileLog, timeout: 60)
        let diagnostic = try Diagnostics.tail(of: compileLog)
        try #require(status == 0, "Native fixture compilation failed: \(diagnostic)")
        let connection = CodexProcessConnection(executable: executable, timeout: .seconds(5))
        let stream = await connection.events()
        let consume = Task { for await _ in stream {} }
        let marker = fixture.home.appendingPathComponent("must-not-exist")
        let text = "$(touch \(marker.path)); `echo unsafe`; quotes ' \" and 🦾"
        let params = WireValue.object(["text": .string(text)])
        let result = try await connection.request("echo", params: params)
        #expect(result == params)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
        let unanswered = Task { try await connection.request("hang", params: .null) }
        await connection.close()
        do {
            _ = try await unanswered.value
            Issue.record("A closed connection must not leave a request pending")
        } catch { #expect(error is ConnectionFailure) }
        await consume.value
    }

    @Test func missingExecutableFailsWithoutLaunchingAnything() async {
        let connection = CodexProcessConnection(executable: nil)
        await #expect(throws: ConnectionFailure.unavailable) {
            try await connection.request("initialize", params: .object([:]))
        }
        await connection.close()
    }
}
