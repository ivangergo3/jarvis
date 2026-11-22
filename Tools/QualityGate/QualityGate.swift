import Foundation
import QualitySupport
import os

@main
enum QualityGate {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments.first == "push" {
                let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                let options = Array(arguments.dropFirst())
                if options.first == "prepare" {
                    try prepare(root: root, options: options)
                } else {
                    try PushGate(root: root).run(options)
                }
                return
            }
            let mode = arguments.first ?? "test"
            var root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            var output: URL?
            var swiftArguments: [String] = []
            var evidence: [String: URL] = [:]
            var index = 1
            while index < arguments.count {
                let value = arguments[index]
                if value.hasPrefix("--swift-arg=") {
                    swiftArguments.append(String(value.dropFirst("--swift-arg=".count)))
                } else if mode == "performance",
                    ["--report", "--baseline", "--policy"].contains(value),
                    index + 1 < arguments.count
                {
                    guard evidence[value] == nil else {
                        throw QualityFailure("Duplicate performance option")
                    }
                    index += 1
                    evidence[value] = URL(fileURLWithPath: arguments[index])
                } else if ["--root", "--output"].contains(value), index + 1 < arguments.count {
                    index += 1
                    let url = URL(fileURLWithPath: arguments[index])
                    if value == "--root" { root = url } else { output = url }
                } else {
                    throw QualityFailure(
                        "Usage: swift run quality-gate [test|mutations|hover-fault|architecture|app-architecture|authority|skills|performance] [--root path] [--output path] [--swift-arg=value]; performance requires --report path, optional --baseline path and --policy path"
                    )
                }
                index += 1
            }
            let destination = output ?? root.appendingPathComponent("test-results")
            switch mode {
            case "performance":
                guard let report = evidence["--report"] else {
                    throw QualityFailure("Performance audit requires --report")
                }
                let result = try PerformanceAudit.run(
                    report: report, baseline: evidence["--baseline"],
                    policy: evidence["--policy"]
                        ?? root.appendingPathComponent("Tools/performance-budgets.json"),
                    output: destination)
                print(
                    "Performance evidence: \(result.conclusion); comparison: \(result.comparison)")
                if result.conclusion == "inconclusive" || result.comparison == "incomparable" {
                    exit(2)
                }
            case "test":
                try WorkspaceArchitecture.check(root: root, output: destination)
                try AppArchitecture.check(root: root, output: destination)
                let summary = try TestGate.run(
                    root: root, swiftArguments: swiftArguments, output: destination)
                print("Tests: \(summary.testCases), passed: \(summary.passed)")
                if let error = summary.error {
                    FileHandle.standardError.write(Data((error + "\n").utf8))
                }
                if !summary.passed { exit(1) }
            case "mutations":
                try FaultProbe.run(root: root, swiftArguments: swiftArguments, output: destination)
            case "architecture":
                try WorkspaceArchitecture.check(root: root, output: destination)
            case "hover-fault":
                try HoverFaultProbe.run(
                    root: root, swiftArguments: swiftArguments, output: destination)
            case "app-architecture":
                try AppArchitecture.check(root: root, output: destination)
            case "authority":
                try AuthorityGate.run(root: root, output: destination)
            case "skills":
                try SkillLayout.check(root: root, output: destination)
            default:
                throw QualityFailure("Unknown quality-gate command: \(mode)")
            }
        } catch {
            FileHandle.standardError.write(
                Data((Diagnostics.redact(error.localizedDescription) + "\n").utf8))
            exit(1)
        }
    }

    private static func prepare(root: URL, options: [String]) throws {
        let interrupted = OSAllocatedUnfairLock(initialState: false)
        let sources = [SIGINT, SIGTERM].map { number in
            let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
            source.setEventHandler { interrupted.withLock { $0 = true } }
            // A caught handler returns to the default disposition in exec'd children.
            let previous = signal(number) { _ in }
            source.resume()
            return (number, previous, source)
        }
        defer {
            for (number, previous, source) in sources {
                source.cancel()
                signal(number, previous)
            }
        }
        try PushGate(root: root) { command, log, timeout in
            try command.run(
                log: log, timeout: timeout, interrupted: { interrupted.withLock { $0 } })
        }.run(options)
    }
}
