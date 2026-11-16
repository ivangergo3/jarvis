import Foundation

public struct GateSummary: Codable, Sendable {
    public var passed = false
    public var testCases = 0
    public var processExit: Int32?
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case passed, error
        case testCases = "test_cases"
        case processExit = "process_exit"
    }
}

public enum TestGate {
    public typealias Runner = (Command, URL, TimeInterval) throws -> Int32

    public static func run(root: URL, swiftArguments: [String] = [], output: URL,
                           runner: Runner = { try $0.run(log: $1, timeout: $2) }) throws -> GateSummary {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let temporary = try TemporaryDirectory(prefix: "jarvis-tests-")
        let log = temporary.url.appendingPathComponent("tests.log")
        let discovery = temporary.url.appendingPathComponent("discovery.log")
        var summary = GateSummary()
        do {
            let command = Command("/usr/bin/env", ["swift", "test"] + swiftArguments + [
                "--xunit-output", temporary.url.appendingPathComponent("results.xml").path
            ], directory: root)
            let status = try runner(command, log, 600)
            summary.processExit = status
            guard status == 0 else {
                throw QualityFailure("Swift test process failed with exit \(status)")
            }
            let list = Command("/usr/bin/env", ["swift", "test", "list", "--skip-build"] + swiftArguments,
                               directory: root)
            guard try runner(list, discovery, 60) == 0 else {
                throw QualityFailure("Test discovery process failed")
            }
            let discovered = TestReport.discovered(in: try String(contentsOf: discovery, encoding: .utf8))
            let required = try JSONDecoder().decode([String].self, from: Data(
                contentsOf: root.appendingPathComponent("Tools/critical-tests.json")))
            let cases = try TestReport.read(TestReport.files(in: temporary.url))
            summary.testCases = try TestReport.validate(cases, discovered: discovered, required: Set(required))
            summary.passed = true
        } catch {
            summary.error = Diagnostics.redact(error.localizedDescription)
        }
        try Diagnostics.writeJSON(summary, to: output.appendingPathComponent("summary.json"))
        let diagnostic = summary.passed ? "" : try Diagnostics.tail(of: log) + "\n" + Diagnostics.tail(of: discovery)
        try diagnostic.write(to: output.appendingPathComponent("failure.log"), atomically: true, encoding: .utf8)
        return summary
    }
}
