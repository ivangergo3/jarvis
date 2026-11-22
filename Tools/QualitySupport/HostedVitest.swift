import Foundation

extension PushGate {
    /// Hosted CI has already prepared the candidate's frozen dependencies and build.
    public func hostedVitest(revision: String, output: URL, complete: CompletePreparation) throws {
        func verifyCheckout() throws {
            try clean()
            guard try commit("HEAD") == revision else {
                throw QualityFailure("Hosted TypeScript checkout differs from the requested commit")
            }
        }
        try verifyCheckout()
        try VitestEvidence.collect(at: output, source: root, revision: revision, runner: runner)
        let verified = try VitestEvidence.validate(
            at: output, repository: self, source: root, revision: revision)
        try verifyCheckout()
        let report = try HostedVitestReport(verified)
        try complete {
            try Diagnostics.writeJSON(report, to: output.appendingPathComponent("qualified.json"))
        }
    }
}

struct HostedVitestReport: Encodable {
    let process: VitestEvidence.Exits
    let passedCaseSHA256: [String]

    init(_ cases: VitestEvidence.VerifiedCases) throws {
        process = cases.exits
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        passedCaseSHA256 = try cases.passed.map {
            VitestEvidence.digest(try encoder.encode([$0.file, $0.name]))
        }.sorted()
    }
}
