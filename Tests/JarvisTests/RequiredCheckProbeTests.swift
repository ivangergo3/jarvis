import Testing

@Suite("Disposable merge-gate probe — do not merge")
struct RequiredCheckProbeTests {
    @Test func requiredCheckMustBlockThisPullRequest() {
        Issue.record("Intentional synthetic failure for issue 44. Close this PR without merging.")
    }
}
