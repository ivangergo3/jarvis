import Foundation
import Testing

@testable import QualitySupport

@Suite("Vitest evidence")
struct VitestEvidenceTests {
    @Test func requiresMatchingDiscoveryResultsAndRequiredCases() throws {
        let attempt = try TemporaryDirectory(prefix: "vitest-evidence-")
        let candidate = attempt.url.appendingPathComponent("candidate")
        let required = attempt.url.appendingPathComponent("required.json")
        try Diagnostics.writeJSON(
            [["file": "fixtures/nested.vitest.ts", "name": "Nesting > works"]], to: required)
        func validate() throws {
            try VitestEvidence.validate(
                at: attempt.url, candidate: candidate, manifest: Data(contentsOf: required),
                revision: "candidate"
            )
        }

        #expect(throws: QualityFailure.self) { try validate() }
        for scenario in [
            "zero", "duplicate", "partial", "missing-required", "skipped", "suite-error", "failed",
            "missing-suite", "other-checkout", "unhandled", "wrong-project", "low-suite-count",
            "stale", "mixed-attempt",
        ] {
            try Self.writeVitest(at: attempt.url, scenario: scenario)
            #expect(throws: QualityFailure.self, Comment(rawValue: scenario)) { try validate() }
        }
        try Self.writeVitest(at: attempt.url)
        try validate()
        // Vitest flattens both a nested title and a literal comparison into its discovery name.
        // A unique passing title containing the separator is valid.
        try Self.writeVitest(at: attempt.url, scenario: "literal-separator")
        try validate()
        try Data("{".utf8).write(to: attempt.url.appendingPathComponent("vitest-results.json"))
        #expect(throws: QualityFailure.self) { try validate() }
    }

    static func writeVitest(
        at output: URL, candidate: URL? = nil, revision: String = "candidate",
        scenario: String = "valid"
    )
        throws
    {
        let checkout = scenario == "other-checkout" ? "candidate-other" : "candidate"
        let candidate = candidate ?? output.appendingPathComponent(checkout)
        let filename = candidate.resolvingSymlinksInPath().appendingPathComponent(
            "fixtures/nested.vitest.ts"
        ).path
        let title = scenario == "missing-required" ? "something else" : "works"
        var id = ["file": filename, "name": "Nesting > " + title]
        if scenario == "wrong-project" { id["projectName"] = "elsewhere" }
        let cases = scenario == "zero" ? [] : (scenario == "duplicate" ? [id, id] : [id])
        try Diagnostics.writeJSON(cases, to: output.appendingPathComponent("vitest-discovery.json"))
        let assertion: [String: Any] = [
            "ancestorTitles": scenario == "literal-separator" ? [] : ["Nesting"],
            "title": scenario == "literal-separator"
                ? "Nesting > works" : (scenario == "partial" ? "different" : title),
            "status": scenario == "skipped" ? "skipped" : "passed", "failureMessages": [],
        ]
        let suite: [String: Any] = [
            "name": filename, "status": scenario == "suite-error" ? "failed" : "passed",
            "assertionResults": [assertion],
        ]
        let suiteCount = scenario == "low-suite-count" ? 1 : 2
        let report: [String: Any] = [
            "success": scenario != "failed", "numTotalTestSuites": suiteCount,
            "numPassedTestSuites": suiteCount,
            "numFailedTestSuites": 0, "numPendingTestSuites": 0, "numTotalTests": cases.count,
            "numPassedTests": cases.count, "numFailedTests": 0, "numPendingTests": 0,
            "numTodoTests": 0, "testResults": scenario == "missing-suite" ? [] : [suite],
        ]
        let data = try JSONSerialization.data(withJSONObject: report)
        try data.write(to: output.appendingPathComponent("vitest-results.json"))
        try Diagnostics.writeJSON(
            VitestEvidence.Exits(
                revision: scenario == "stale" ? "earlier" : revision, discovery: 0,
                execution: scenario == "unhandled" ? 1 : 0,
                discoverySHA256: VitestEvidence.digest(
                    try Data(contentsOf: output.appendingPathComponent("vitest-discovery.json"))),
                executionSHA256: scenario == "mixed-attempt"
                    ? "different" : VitestEvidence.digest(data)),
            to: output.appendingPathComponent("process.json"))
    }
}
