import Foundation

public enum FaultProbe {
    private struct Fault {
        let name: String
        let path: String
        let before: String
        let after: String
        let test: String
    }

    private struct Evidence: Encodable {
        let fault: String
        let test: String
        let defective: Bool
        let exit: Int32
        let assertionFailed: Bool

        enum CodingKeys: String, CodingKey {
            case fault, test, defective, exit
            case assertionFailed = "assertion_failed"
        }
    }

    private static let faults = [
        Fault(
            name: "authority destination", path: "Sources/JarvisAuthority/AuthoritySession.swift",
            before: "grant.destination == proposal.destination", after: "true",
            test:
                "QualitySupportTests.AuthorityTests/stableDestinationResourcesAndCapabilitiesAreNotInterchangeable"
        ),
        Fault(
            name: "private data export", path: "Sources/JarvisAuthority/AuthoritySession.swift",
            before: "!proposal.kind.exportsData || resource.classification == .publicData",
            after: "true",
            test:
                "QualitySupportTests.AuthorityTests/privateAndCredentialResourcesCannotBeExportedEvenWithASendGrant"
        ),
        Fault(
            name: "object-only protocol", path: "Sources/Jarvis/Shared/ConnectionContracts.swift",
            before: "case .object = value", after: "true",
            test: "JarvisTests.ProtocolBoundaryTests/validJSONThatIsNotAnObjectIsRejected"),
        Fault(
            name: "stale refresh revision", path: "Sources/Jarvis/Application/CompanionModel.swift",
            before: "revision == historyRevision", after: "revision == revision",
            test:
                "JarvisTests.ConversationRegressionTests/historyStartedBeforeSendCannotEraseTheQueuedMessage"
        ),
        Fault(
            name: "stale lifecycle boundary", path: "Sources/JarvisWorkspace/CodexReader.swift",
            before: "readAt.timeIntervalSince(date) > 1800",
            after: "readAt.timeIntervalSince(date) >= 1800",
            test: "JarvisTests.LifecycleBoundaryTests/startMarkerExpiresOnlyAfterThirtyMinutes"),
    ]

    /// This slower explicit diagnostic mutates only an owned temporary source copy.
    public static func run(root: URL, swiftArguments: [String], output: URL) throws {
        let temporary = try TemporaryDirectory(prefix: "jarvis-faults-")
        let copy = temporary.url
        let files = FileManager.default
        for name in ["Sources", "Tests", "Tools", "Package.swift"] {
            try files.copyItem(
                at: root.appendingPathComponent(name), to: copy.appendingPathComponent(name))
        }
        var evidence: [Evidence] = []
        for fault in faults {
            let source = copy.appendingPathComponent(fault.path)
            let original = try String(contentsOf: source, encoding: .utf8)
            guard original.components(separatedBy: fault.before).count == 2 else {
                throw QualityFailure("Mutation anchor changed: \(fault.name); review the fault")
            }
            for defective in [false, true, false] {
                let contents =
                    defective
                    ? original.replacingOccurrences(of: fault.before, with: fault.after) : original
                try contents.write(to: source, atomically: true, encoding: .utf8)
                for report in try TestReport.files(in: copy) { try files.removeItem(at: report) }
                let log = copy.appendingPathComponent("test.log")
                let command = Command(
                    "/usr/bin/env",
                    ["swift", "test"] + swiftArguments + [
                        "--filter", fault.test, "--xunit-output",
                        copy.appendingPathComponent("result.xml").path,
                    ], directory: copy)
                let status = try command.run(log: log, timeout: 600)
                let cases = try TestReport.read(
                    TestReport.files(in: copy), allowReportedIssues: true)
                let matching = cases.filter { $0.id == fault.test }
                let failed = matching.contains(where: \.failed)
                guard matching.count == 1, !cases.contains(where: \.skipped),
                    defective ? (status != 0 && failed) : (status == 0 && !failed)
                else {
                    FileHandle.standardError.write(Data(try Diagnostics.tail(of: log).utf8))
                    throw QualityFailure(
                        "Unexpected fault-probe outcome: \(fault.name), defective=\(defective)")
                }
                evidence.append(
                    Evidence(
                        fault: fault.name, test: fault.test, defective: defective,
                        exit: status, assertionFailed: failed))
                print(
                    "\(fault.name): defective=\(defective), exit=\(status), assertion_failed=\(failed)"
                )
            }
        }
        try files.createDirectory(at: output, withIntermediateDirectories: true)
        try Diagnostics.writeJSON(evidence, to: output.appendingPathComponent("fault-probes.json"))
    }
}
