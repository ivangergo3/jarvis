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
}
