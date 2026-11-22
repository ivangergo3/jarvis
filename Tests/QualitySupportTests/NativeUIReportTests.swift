import QualitySupport
import Testing

@Suite("Native UI result gate")
struct NativeUIReportTests {
    let discovery: [String: Any] = [
        "tests": [["name": "testSelection()"], ["name": "testDrafts()"]]
    ]
    let summary: [String: Any] = [
        "failedTests": 0, "skippedTests": 0, "passedTests": 2, "totalTestCount": 2,
    ]

    @Test func validatesDiscoveryAgainstExecutedTests() throws {
        let results = [
            "children": [
                ["nodeIdentifier": "JarvisUITests/testSelection()"],
                ["nodeIdentifier": "JarvisUITests/testDrafts()"],
            ]
        ]
        #expect(
            try NativeUIReport.validate(
                discovery: discovery, results: results, summary: summary,
                required: ["testSelection", "testDrafts"]) == 2)
    }

    @Test func rejectsOmittedTestsAndEmptyDiscovery() {
        #expect(throws: QualityFailure.self) {
            try NativeUIReport.validate(
                discovery: discovery, results: ["name": "testSelection()"],
                summary: summary, required: ["testSelection", "testDrafts"])
        }
        #expect(throws: QualityFailure.self) {
            try NativeUIReport.validate(
                discovery: [:], results: [:], summary: summary, required: [])
        }
    }

    @Test func greenInventoryCannotHideFailuresOrSkips() {
        for field in ["failedTests", "skippedTests"] {
            var broken = summary
            broken[field] = 1
            #expect(throws: QualityFailure.self) {
                try NativeUIReport.validate(
                    discovery: discovery, results: discovery, summary: broken,
                    required: ["testSelection"])
            }
        }
    }

    @Test func complementaryShardsExecuteEveryDiscoveredJourney() throws {
        let primary = NativeUIReport.Shard.interactions
        let remaining = NativeUIReport.Shard.remaining
        let anchor = [
            "testEmptyProject", "testKeyboardNavigationAndDraftDestination",
            "testViewModesSettingsAndPanelVisibilityPreserveDraft",
        ]
        let required = Set(anchor + ["testEmptyWorkspace"])
        let extra = ["testEmptyWorkspace", "testNewJourney"]
        let all = anchor + extra
        func checked(_ shard: NativeUIReport.Shard, _ results: [String]) throws -> Int {
            try NativeUIReport.validate(
                discovery: all, results: results,
                summary: [
                    "passedTests": results.count, "totalTestCount": results.count,
                    "failedTests": 0, "skippedTests": 0,
                ], required: required, shard: shard)
        }
        #expect(
            primary.xcodeFilters == anchor.map { "-only-testing:JarvisUITests/JarvisUITests/" + $0 }
        )
        #expect(
            remaining.xcodeFilters
                == anchor.map { "-skip-testing:JarvisUITests/JarvisUITests/" + $0 })
        #expect(try checked(primary, anchor) == 3)
        #expect(try checked(remaining, extra) == 2)
        #expect(throws: QualityFailure.self) { try checked(primary, extra) }
        #expect(throws: QualityFailure.self) { try checked(remaining, ["testEmptyWorkspace"]) }
        #expect(throws: QualityFailure.self) { try checked(remaining, all) }
        #expect(throws: QualityFailure.self) {
            try NativeUIReport.validate(
                discovery: extra, results: extra, summary: summary, required: required,
                shard: remaining)
        }
    }
}
