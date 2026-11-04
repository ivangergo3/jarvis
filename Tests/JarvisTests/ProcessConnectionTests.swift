import Foundation
import Testing

@testable import Jarvis

@Suite("App Server subprocess boundary")
struct ProcessConnectionTests {
    @Test func literalTextRoundTripsWithoutShellExecutionAndCloseReleasesPendingCalls() async throws
    {
        let fixture = try SessionFixture()
        let script = fixture.home.appendingPathComponent("fake-codex")
        try Data(
            """
            #!/usr/bin/python3
            import json, sys
            for line in sys.stdin:
                value = json.loads(line)
                if value.get('method') == 'hang':
                    continue
                if 'id' in value:
                    print(json.dumps({'id': value['id'], 'result': value.get('params', {})}), flush=True)
            """.utf8
        ).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        let connection = CodexProcessConnection(executable: script, timeout: .seconds(5))
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
