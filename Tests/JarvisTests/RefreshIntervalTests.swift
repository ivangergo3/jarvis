import Testing
@testable import Jarvis

@Suite("Refresh settings") struct RefreshIntervalTests {
    @Test func supportedPreferencesRoundTrip() {
        for interval in RefreshInterval.allCases {
            #expect(RefreshInterval.restoring(interval.rawValue) == interval)
        }
    }
    @Test func invalidOrMissingPreferencesUseSafeDefault() {
        for value in [0, -1, 2, 999, Int.max] {
            #expect(RefreshInterval.restoring(value) == .normal)
        }
    }
}
