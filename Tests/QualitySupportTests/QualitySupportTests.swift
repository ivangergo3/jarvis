import Foundation
import Testing

@testable import QualitySupport

@Suite("Native Swift quality gate", .timeLimit(.minutes(1)))
struct QualitySupportTests {
    private let example = "JarvisTests.Suite/example"
    private let valid =
        "<testsuite><testcase classname=\"JarvisTests.Suite\" name=\"example()\"/></testsuite>"

    private func read(_ xml: String) throws -> [TestCase] {
        let temporary = try TemporaryDirectory(prefix: "quality-report-")
        let report = temporary.url.appendingPathComponent("report.xml")
        try xml.write(to: report, atomically: true, encoding: .utf8)
        return try TestReport.read([report])
    }

    @Test func validResultsRequireTheCompleteDiscoveredAndCriticalInventory() throws {
        let cases = try read(valid)
        #expect(try TestReport.validate(cases, discovered: [example], required: [example]) == 1)
        for (discovered, required): (Set<String>, Set<String>) in [
            ([], []), (["JarvisTests.Suite/other"], []), ([example], ["JarvisTests.Suite/removed"]),
            ([], [example]),
        ] {
            #expect(throws: QualityFailure.self) {
                try TestReport.validate(cases, discovered: discovered, required: required)
            }
        }
        #expect(throws: QualityFailure.self) {
            try TestReport.validate([], discovered: [example], required: [])
        }
    }

    @Test func malformedMissingOversizedOrSkippedResultsCannotPass() throws {
        for xml in [
            "<broken", "<testsuite skipped=\"1\"/>", "<testsuite errors=\"1\"/>",
            "<!DOCTYPE testsuite><testsuite/>",
            "<testsuite><testcase classname=\"JarvisTests.Suite\" name=\"example()\"><skipped/></testcase></testsuite>",
            "<testsuite><testcase classname=\"JarvisTests.Suite\" name=\"example()\"><failure/></testcase></testsuite>",
            "<testsuite><testcase status=\"disabled\"/></testsuite>", "<testsuites/>",
        ] {
            #expect(throws: QualityFailure.self) {
                try TestReport.validate(read(xml), discovered: [example], required: [])
            }
        }
        #expect(throws: QualityFailure.self) {
            try read(String(repeating: " ", count: 8 * 1024 * 1024 + 1))
        }
        #expect(try TestReport.read([]).isEmpty)
    }

    @Test func discoveryRecognisesBothTestModulesAndIgnoresCompilerOutput() {
        #expect(
            TestReport.discovered(
                in: """
                    Building tests...
                    JarvisTests.Suite/example()
                    QualitySupportTests.QualitySupportTests/nativeCheck()
                    """) == [example, "QualitySupportTests.QualitySupportTests/nativeCheck"])
    }

    @Test func nonzeroExitSignalAndTimeoutAreFailures() throws {
        let temporary = try TemporaryDirectory(prefix: "quality-process-")
        let log = temporary.url.appendingPathComponent("process.log")
        #expect(
            try Command("/bin/bash", ["-c", "exit 7"], directory: temporary.url)
                .run(log: log, timeout: 5) == 7)
        #expect(
            try Command("/bin/bash", ["-c", "kill -TERM $$"], directory: temporary.url)
                .run(log: log, timeout: 5) == -15)
        #expect(throws: QualityFailure.self) {
            try Command("/bin/sleep", ["30"], directory: temporary.url).run(log: log, timeout: 0.1)
        }
    }

    @Test func timeoutAlsoStopsDescendants() throws {
        let temporary = try TemporaryDirectory(prefix: "quality-descendant-")
        let log = temporary.url.appendingPathComponent("process.log")
        let marker = temporary.url.appendingPathComponent("child.pid")
        // Fixed shell code; paths are positional arguments, never interpolated into shell text.
        #expect(throws: QualityFailure.self) {
            try Command(
                "/bin/bash", ["-c", "sleep 30 & echo $! > \"$1\"; wait", "fixture", marker.path],
                directory: temporary.url
            ).run(log: log, timeout: 1)
        }
        let pidText = try String(contentsOf: marker, encoding: .utf8).trimmingCharacters(
            in: .whitespacesAndNewlines)
        let pid = try #require(Int32(pidText))
        // A just-killed child can briefly remain a zombie until reaped; neither state can run.
        let stateLog = temporary.url.appendingPathComponent("state.log")
        _ = try Command("/bin/ps", ["-o", "stat=", "-p", String(pid)], directory: temporary.url)
            .run(log: stateLog, timeout: 5)
        let state = try String(contentsOf: stateLog, encoding: .utf8).trimmingCharacters(
            in: .whitespacesAndNewlines)
        #expect(state.isEmpty || state.hasPrefix("Z"))
    }

    @Test func diagnosticsAreBoundedAndRedactPathsQuotedCredentialsAndBearerValues() throws {
        let temporary = try TemporaryDirectory(prefix: "quality-diagnostics-")
        let log = temporary.url.appendingPathComponent("output.log")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        try
            (String(repeating: "x", count: Diagnostics.tailLimit * 2)
            + "\n\(home)/private.txt token=synthetic-secret\n")
            .write(to: log, atomically: true, encoding: .utf8)
        let tail = try Diagnostics.tail(of: log)
        #expect(tail.utf8.count <= Diagnostics.tailLimit)
        #expect(!tail.contains(home))
        #expect(!tail.contains("synthetic-secret"))
        for value in [
            #"{"token":"synthetic-secret"}"#, "Authorization: Bearer synthetic-secret",
            "password='synthetic-secret'",
        ] {
            #expect(!Diagnostics.redact(value).contains("synthetic-secret"))
        }
    }

    @Test func greenXMLCannotOverrideAFailedProcess() throws {
        let temporary = try TemporaryDirectory(prefix: "quality-gate-")
        let summary = try TestGate.run(
            root: temporary.url, output: temporary.url.appendingPathComponent("results")
        ) {
            command, log, _ in
            let index = try #require(command.arguments.firstIndex(of: "--xunit-output"))
            try valid.write(toFile: command.arguments[index + 1], atomically: true, encoding: .utf8)
            try "Synthetic failure".write(to: log, atomically: true, encoding: .utf8)
            return 7
        }
        #expect(!summary.passed)
        #expect(summary.processExit == 7)
    }
}
