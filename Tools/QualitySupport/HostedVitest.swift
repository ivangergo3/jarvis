import Foundation

extension PushGate {
    /// Hosted CI has already prepared the candidate's frozen dependencies and build.
    public func hostedVitest(revision: String, output: URL) throws {
        func verifyCheckout() throws {
            try clean()
            guard try commit("HEAD") == revision else {
                throw QualityFailure("Hosted TypeScript checkout differs from the requested commit")
            }
        }
        try verifyCheckout()
        try VitestEvidence.collect(at: output, source: root, revision: revision, runner: runner)
        try VitestEvidence.validate(at: output, repository: self, source: root, revision: revision)
        try verifyCheckout()
    }
}
