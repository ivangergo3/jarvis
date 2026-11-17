import Foundation

public enum HoverFaultProbe {
    /// Reproduce the former broad invalidation effect only in an owned disposable copy.
    public static func run(root: URL, swiftArguments: [String], output: URL) throws {
        let fixture = try TemporaryDirectory(prefix: "jarvis-hover-fault-")
        for name in ["Sources", "Tests", "Tools", "Package.swift"] {
            try FileManager.default.copyItem(
                at: root.appendingPathComponent(name),
                to: fixture.url.appendingPathComponent(name))
        }
        let file = fixture.url.appendingPathComponent(
            "Sources/Jarvis/Application/DashboardState.swift")
        let original = try String(contentsOf: file, encoding: .utf8)
        let classAnchor = "@MainActor final class DashboardState: ObservableObject {"
        let assignment = "        projectID = stored == \"__all__\" ? nil : stored"
        guard original.components(separatedBy: classAnchor).count == 2,
            original.components(separatedBy: assignment).count == 2
        else {
            throw QualityFailure("Hover fault anchors changed; review the disposable mutation")
        }
        let defective =
            original
            .replacingOccurrences(
                of: classAnchor,
                with: classAnchor + "\n    private var seededForwarder: AnyCancellable?"
            )
            .replacingOccurrences(
                of: assignment,
                with: assignment
                    + "\n        seededForwarder = graphHover.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }"
            )
        let selected =
            "JarvisTests.PerformanceRegressionTests/sustainedHoverDoesNotInvalidateDashboardOrConversation"
        struct Evidence: Encodable {
            let fault: String
            let defective: Bool
            let exit: Int32
            let assertionFailed: Bool
        }
        var evidence: [Evidence] = []
        let cardFile = fixture.url.appendingPathComponent(
            "Sources/Jarvis/Application/GraphHoverState.swift")
        let cardOriginal = try String(contentsOf: cardFile, encoding: .utf8)
        let cardAnchor = "        guard next != nodeID else { return }"
        guard cardOriginal.components(separatedBy: cardAnchor).count == 2 else {
            throw QualityFailure("Card fanout fault anchor changed")
        }
        let cardDefective = cardOriginal.replacingOccurrences(
            of: cardAnchor,
            with: cardAnchor
                + "\n        for state in destinations.values { state.value?.objectWillChange.send() }"
        )
        for (name, target, good, bad, test, assertion) in [
            ("dashboard-forwarding", file, original, defective, selected, "rootUpdates"),
            (
                "all-card-fanout", cardFile, cardOriginal, cardDefective,
                "JarvisTests.PerformanceRegressionTests/hoverLoadOnlyNotifiesChangedCards",
                "notifications"
            ),
        ] {
            for fault in [false, true, false] {
                try (fault ? bad : good).write(to: target, atomically: true, encoding: .utf8)
                for xml in try TestReport.files(in: fixture.url) {
                    try FileManager.default.removeItem(at: xml)
                }
                let log = fixture.url.appendingPathComponent("test.log")
                let command = Command(
                    "/usr/bin/env",
                    ["swift", "test"] + swiftArguments + [
                        "--filter", test, "--xunit-output",
                        fixture.url.appendingPathComponent("result.xml").path,
                    ], directory: fixture.url)
                let status = try command.run(log: log, timeout: 600)
                let cases = try TestReport.read(
                    TestReport.files(in: fixture.url), allowReportedIssues: true)
                let matches = cases.filter { $0.id == TestReport.id(test) }
                let failed = matches.contains(where: \.failed)
                let tail = try Diagnostics.tail(of: log)
                // Swift Testing reports the five argument sets as one xUnit testcase.
                guard matches.count == 1,
                    !cases.contains(where: \.skipped),
                    fault
                        ? (status != 0 && failed && tail.contains(assertion))
                        : (status == 0 && !failed)
                else {
                    FileHandle.standardError.write(Data(tail.utf8))
                    throw QualityFailure("Unexpected hover regression probe outcome")
                }
                evidence.append(
                    Evidence(fault: name, defective: fault, exit: status, assertionFailed: failed))
                print(
                    "Hover \(name): defective=\(fault), exit=\(status), assertion_failed=\(failed)"
                )
            }
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try Diagnostics.writeJSON(evidence, to: output.appendingPathComponent("hover-fault.json"))
    }
}
