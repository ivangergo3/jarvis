import CryptoKit
import Darwin
import Foundation

enum VitestEvidence {
    struct Case: Decodable, Hashable {
        let file: String
        let name: String
        var projectName: String?
    }

    struct Exits: Codable {
        let revision: String
        let discovery: Int32?
        let execution: Int32?
        let discoverySHA256: String?
        let executionSHA256: String?
    }

    private struct Report: Decodable {
        struct Suite: Decodable {
            struct Assertion: Decodable {
                let ancestorTitles: [String]
                let title: String
                let status: String
                let failureMessages: [String]
            }
            let name: String
            let status: String
            let assertionResults: [Assertion]
        }
        let success: Bool
        let numTotalTestSuites, numPassedTestSuites, numFailedTestSuites, numPendingTestSuites: Int
        let numTotalTests, numPassedTests, numFailedTests, numPendingTests, numTodoTests: Int
        let testResults: [Suite]
    }

    // A successful prepare removes its candidate. Resolve the existing ancestor so macOS
    // temporary-directory aliases compare the same before and after worktree cleanup.
    private static func physicalPath(_ url: URL) throws -> String {
        if let path = realpath(url.path, nil) {
            defer { free(path) }
            return String(cString: path)
        }
        let parent = url.deletingLastPathComponent()
        guard errno == ENOENT, parent.path != url.path else {
            throw QualityFailure("Cannot resolve Vitest evidence path")
        }
        return try physicalPath(parent) + "/" + url.lastPathComponent
    }

    static func collect(at reports: URL, source: URL, revision: String, runner: TestGate.Runner)
        throws
    {
        try FileManager.default.createDirectory(
            at: reports, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let inventory = reports.appendingPathComponent("vitest-discovery.json")
        let results = reports.appendingPathComponent("vitest-results.json")
        var discovery: Int32?
        var execution: Int32?
        var inventoryDigest: String?
        var resultsDigest: String?
        func reportDigest(_ url: URL) -> String? {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                attributes[.type] as? FileAttributeType == .typeRegular,
                let data = try? Data(contentsOf: url)
            else { return nil }
            return digest(data)
        }
        func record() throws {
            let exits = Exits(
                revision: revision, discovery: discovery, execution: execution,
                discoverySHA256: inventoryDigest, executionSHA256: resultsDigest)
            try Diagnostics.writeJSON(exits, to: reports.appendingPathComponent("process.json"))
        }
        try record()
        discovery = try runner(
            Command(
                "/usr/bin/env",
                [
                    "pnpm", "exec", "vitest", "list", "--allowOnly=false",
                    "--json=" + inventory.path,
                ], directory: source), reports.appendingPathComponent("discovery.log"), 300)
        inventoryDigest = reportDigest(inventory)
        try record()
        guard discovery == 0, inventoryDigest != nil else {
            throw QualityFailure("Vitest discovery failed; inspect discovery.log")
        }
        guard (try? FileManager.default.attributesOfItem(atPath: results.path)) == nil else {
            throw QualityFailure("Vitest result already exists before execution")
        }
        execution = try runner(
            Command(
                "/usr/bin/env",
                [
                    "pnpm", "exec", "vitest", "run", "--allowOnly=false",
                    "--maxWorkers=1", "--reporter=json", "--outputFile=" + results.path,
                ], directory: source),
            reports.appendingPathComponent("execution.log"), 900)
        resultsDigest = reportDigest(results)
        try record()
        guard execution == 0, resultsDigest != nil else {
            throw QualityFailure("Vitest execution failed; inspect execution.log")
        }
    }

    static func validate(at attempt: URL, repository: PushGate, source: URL, revision: String)
        throws
    {
        let manifest = try repository.git(["show", revision + ":Tools/required-vitest.json"])
        try validate(
            at: attempt, candidate: source, manifest: Data(manifest.utf8), revision: revision)
    }

    static func validate(at attempt: URL, candidate: URL, manifest: Data, revision: String)
        throws
    {
        for file in ["vitest-discovery.json", "vitest-results.json", "process.json"] {
            guard FileManager.default.fileExists(atPath: attempt.appendingPathComponent(file).path)
            else { throw QualityFailure("Missing Vitest discovery or result evidence") }
        }
        let decoder = JSONDecoder()
        let exits = try decoder.decode(
            Exits.self, from: Data(contentsOf: attempt.appendingPathComponent("process.json")))
        guard exits.revision == revision else {
            throw QualityFailure("Vitest reports refer to a different commit")
        }
        guard exits.discovery == 0, exits.execution == 0 else {
            throw QualityFailure("Vitest process failed; inspect discovery.log and execution.log")
        }
        let required = try decoder.decode([Case].self, from: manifest)
        let inventory = try Data(
            contentsOf: attempt.appendingPathComponent("vitest-discovery.json"))
        let results = try Data(contentsOf: attempt.appendingPathComponent("vitest-results.json"))
        guard digest(inventory) == exits.discoverySHA256, digest(results) == exits.executionSHA256
        else {
            throw QualityFailure("Vitest process status and report digests differ")
        }
        let discovery = try decoder.decode([Case].self, from: inventory)
        let report = try decoder.decode(Report.self, from: results)
        let source = try physicalPath(candidate) + "/"
        func relative(_ file: String) throws -> String {
            guard file.hasPrefix("/"), !file.split(separator: "/").contains("..") else {
                throw QualityFailure("Expected an absolute Vitest file path without backtracking")
            }
            let path = try physicalPath(URL(fileURLWithPath: file))
            guard path.hasPrefix(source), path.count > source.count else {
                throw QualityFailure("Vitest case belongs to another checkout")
            }
            return String(path.dropFirst(source.count))
        }

        let collected = try Set(
            discovery.map { item in
                guard item.projectName == nil, !item.name.isEmpty else {
                    throw QualityFailure(
                        "Expected named tests from the single default Vitest project")
                }
                return try Case(file: relative(item.file), name: item.name)
            })
        var passed = Set<Case>()
        var files = Set<String>()
        var minimumSuites = 0
        guard report.success, !collected.isEmpty, collected.count == discovery.count,
            !required.isEmpty, Set(required).count == required.count,
            Set(required).isSubset(of: collected),
            report.numTotalTestSuites >= report.testResults.count,
            report.numTotalTestSuites == report.numPassedTestSuites,
            report.numFailedTestSuites == 0, report.numPendingTestSuites == 0,
            report.numTotalTests == collected.count, report.numPassedTests == collected.count,
            report.numFailedTests == 0, report.numPendingTests == 0, report.numTodoTests == 0
        else { throw QualityFailure("Vitest inventory, totals or required cases are incomplete") }
        for suite in report.testResults {
            let file = try relative(suite.name)
            guard suite.status == "passed", files.insert(file).inserted,
                !suite.assertionResults.isEmpty
            else { throw QualityFailure("Vitest suite failed, repeated or empty") }
            var nestedSuites: Set<[String]> = [[]]
            for assertion in suite.assertionResults {
                // Vitest list joins nested suite names with " > ". The JSON reporter exposes their parts.
                let titles = assertion.ancestorTitles + [assertion.title]
                guard titles.allSatisfy({ !$0.isEmpty }) else {
                    throw QualityFailure("Vitest case or suite title is empty")
                }
                let name = titles.joined(separator: " > ")
                let id = Case(file: file, name: name)
                for index in assertion.ancestorTitles.indices {
                    nestedSuites.insert(Array(assertion.ancestorTitles[...index]))
                }
                guard assertion.status == "passed", assertion.failureMessages.isEmpty,
                    passed.insert(id).inserted
                else { throw QualityFailure("Vitest case failed, skipped or repeated") }
            }
            minimumSuites += nestedSuites.count
        }
        guard passed == collected, report.numTotalTestSuites >= minimumSuites else {
            throw QualityFailure("Vitest discovery and results differ")
        }
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
