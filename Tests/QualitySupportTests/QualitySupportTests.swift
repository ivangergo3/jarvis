import Darwin
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

    @Test func signaledCompletionAfterDeadlineCannotReportAnExitStatus() throws {
        let completion = DispatchSemaphore(value: 0)
        completion.signal()
        #expect(throws: CommandCleanupFailure.self) {
            try Command.observedCompletion(completion, until: .now(), deadline: .now())
        }
        let future = DispatchTime.now() + 30
        #expect(try !Command.observedCompletion(completion, until: .now(), deadline: future))
        completion.signal()
        #expect(try Command.observedCompletion(completion, until: future, deadline: future))
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

    private func supervisor(in workspace: TemporaryDirectory, log: URL) throws -> URL {
        let directory = workspace.url
        let source = directory.appendingPathComponent("main.swift")
        let executable = directory.appendingPathComponent("supervisor")
        try """
        import Darwin
        import Foundation
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        var info = proc_bsdinfo()
        let size = withUnsafeMutableBytes(of: &info) {
            proc_pidinfo(child.processIdentifier, PROC_PIDTBSDINFO, 0, $0.baseAddress, Int32($0.count))
        }
        guard size == MemoryLayout<proc_bsdinfo>.stride else { throw NSError(domain: "SyntheticFixture", code: 1) }
        let record = [String(child.processIdentifier), String(getpgid(child.processIdentifier)),
            String(getpgrp()), String(info.pbi_start_tvsec), String(info.pbi_start_tvusec)].joined(separator: ",")
        try record.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
        if CommandLine.arguments.contains("--exit") { exit(0) }
        child.waitUntilExit()
        """.write(to: source, atomically: true, encoding: .utf8)
        try #require(
            try workspace.retainingOnCleanupFailure({
                try Command(
                    "/usr/bin/xcrun",
                    ["swiftc", "-swift-version", "6", source.path, "-o", executable.path],
                    directory: directory
                ).run(log: log, timeout: 30)
            }) == 0)
        return executable
    }

    private func recordedChild(_ marker: URL) throws -> (OwnedProcessTree.Node, pid_t) {
        let fields = try String(contentsOf: marker, encoding: .utf8).split(separator: ",")
        try #require(fields.count == 5)
        let pid = try #require(Int32(fields[0]))
        let group = try #require(Int32(fields[1]))
        let parentGroup = try #require(Int32(fields[2]))
        #expect(group == pid && group != parentGroup)
        return (
            try OwnedProcessTree.Node(
                pid: pid, seconds: #require(UInt64(fields[3])),
                microseconds: #require(UInt64(fields[4]))), parentGroup
        )
    }

    private func cleanup(_ node: OwnedProcessTree.Node, workspace: TemporaryDirectory) {
        do {
            try OwnedProcessTree.killMatching(node)
            try OwnedProcessTree.confirmExit(
                node, before: ContinuousClock().now.advanced(by: .seconds(2)))
        } catch {
            workspace.retain(reason: "synthetic worker cleanup is uncertain")
            Issue.record(error)
        }
    }

    @Test func ownedExitCanBeConfirmedBeforeChildIsReaped() throws {
        // Foundation.Process automatically reaps its child. Use POSIX here to hold
        // the exited fixture at the exact state reached during nested cleanup.
        var pid: pid_t = 0
        let executable = try #require(strdup("/usr/bin/true"))
        defer { free(executable) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [executable, nil]
        try #require(posix_spawn(&pid, executable, nil, nil, &arguments, nil) == 0)
        defer { while waitpid(pid, nil, 0) == -1 && errno == EINTR {} }

        var exitInfo = siginfo_t()
        var result: Int32
        repeat {
            result = waitid(P_PID, id_t(pid), &exitInfo, WEXITED | WNOWAIT)
        } while result == -1 && errno == EINTR
        try #require(result == 0)

        let info = try #require(try OwnedProcessTree.inspect(pid))
        #expect(info.pbi_pid == UInt32(pid))
        #expect(info.pbi_status == UInt32(SZOMB))
        let child = OwnedProcessTree.Node(
            pid: pid, seconds: info.pbi_start_tvsec, microseconds: info.pbi_start_tvusec)
        try OwnedProcessTree.confirmExit(child, before: ContinuousClock().now)
    }

    @Test func timeoutStopsNestedIsolatedProcessGroups() throws {

        let temporary = try TemporaryDirectory(prefix: "quality-nested-")
        let marker = temporary.url.appendingPathComponent("child.pid")
        let log = temporary.url.appendingPathComponent("process.log")
        let executable = try supervisor(in: temporary, log: log)
        #expect(throws: QualityFailure.self) {
            try temporary.retainingOnCleanupFailure {
                try Command(executable.path, [marker.path], directory: temporary.url).run(
                    log: log, timeout: 10)
            }
        }
        guard FileManager.default.fileExists(atPath: marker.path) else {
            temporary.retain(reason: "nested timeout fixture did not become ready")
            throw QualityFailure(
                "Nested timeout fixture did not become ready: " + (try Diagnostics.tail(of: log)))
        }
        let (node, _) = try recordedChild(marker)
        defer { cleanup(node, workspace: temporary) }
        let state = temporary.url.appendingPathComponent("state.log")
        _ = try Command(
            "/bin/ps", ["-o", "stat=", "-p", String(node.pid)], directory: temporary.url
        )
        .run(log: state, timeout: 5)
        let observed = try String(contentsOf: state, encoding: .utf8).trimmingCharacters(
            in: .whitespacesAndNewlines)
        #expect(observed.isEmpty || observed.hasPrefix("Z"))
    }

    @Test func anExitedTimeoutSupervisorReportsUncertainOwnership() throws {
        let fixture = try TemporaryDirectory(prefix: "exited-supervisor-")
        let marker = fixture.url.appendingPathComponent("child.pid")
        let executable = try supervisor(
            in: fixture, log: fixture.url.appendingPathComponent("compile.log"))
        let root = Process()
        root.executableURL = executable
        root.arguments = [marker.path, "--exit"]
        root.standardInput = FileHandle.nullDevice
        root.standardOutput = FileHandle.nullDevice
        root.standardError = FileHandle.nullDevice
        try root.run()
        root.waitUntilExit()
        let (node, parentGroup) = try recordedChild(marker)
        #expect(parentGroup == root.processIdentifier)
        defer { cleanup(node, workspace: fixture) }
        #expect(try OwnedProcessTree.inspect(node.pid).map { node.matches($0) } == true)
        let finished = DispatchSemaphore(value: 0)
        finished.signal()
        #expect(throws: CommandCleanupFailure.self) {
            try Command.timedOut(root, finished: finished)
        }
        let secondMarker = fixture.url.appendingPathComponent("interrupted-child.pid")
        defer {
            if let (child, _) = try? recordedChild(secondMarker) {
                cleanup(child, workspace: fixture)
            }
        }
        #expect(throws: CommandCleanupFailure.self) {
            try Command(executable.path, [secondMarker.path, "--exit"], directory: fixture.url)
                .run(log: fixture.url.appendingPathComponent("interrupt.log"), timeout: 10) {
                    guard let (_, parent) = try? recordedChild(secondMarker) else { return false }
                    return kill(parent, 0) == -1 && errno == ESRCH
                }
        }
    }

    @Test func uncertainCleanupRetainsOwnedWorkspacesAndFailedSummary() throws {
        let fixture = try TemporaryDirectory(prefix: "retention-test-")
        var retained: URL?
        do {
            let owned = try TemporaryDirectory(prefix: "owned-", parent: fixture.url)
            retained = owned.url
            #expect(throws: CommandCleanupFailure.self) {
                try owned.retainingOnCleanupFailure {
                    throw CommandCleanupFailure(detail: "synthetic uncertainty")
                }
            }
        }
        #expect(FileManager.default.fileExists(atPath: try #require(retained).path))
        var diagnostics: URL?
        let summary = try TestGate.run(
            root: fixture.url, output: fixture.url.appendingPathComponent("results")
        ) { command, _, _ in
            let index = try #require(command.arguments.firstIndex(of: "--xunit-output"))
            diagnostics = URL(fileURLWithPath: command.arguments[index + 1])
                .deletingLastPathComponent()
            throw CommandCleanupFailure(detail: "synthetic uncertainty")
        }
        let preserved = try #require(diagnostics)
        // No process was launched by this fake.
        defer { try? FileManager.default.removeItem(at: preserved) }
        #expect(!summary.passed && summary.cleanupUncertain)
        #expect(FileManager.default.fileExists(atPath: preserved.path))
        #expect(throws: CommandCleanupFailure.self) { try OwnedProcessTree.terminate(getpid()) }
    }

    @Test func ownedProcessIdentityRejectsReusedPIDs() {
        let node = OwnedProcessTree.Node(pid: 123, seconds: 10, microseconds: 20)
        var info = proc_bsdinfo()
        info.pbi_pid = 123
        info.pbi_start_tvsec = 10
        info.pbi_start_tvusec = 20
        #expect(node.matches(info))
        info.pbi_start_tvusec = 21
        #expect(!node.matches(info))
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
