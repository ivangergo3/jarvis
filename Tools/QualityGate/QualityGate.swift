import Darwin
import Foundation
import QualitySupport

@main
enum QualityGate {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments.first == "hosted-vitest" {
                guard arguments.count == 3, arguments[2].hasPrefix("/") else {
                    throw QualityFailure("Usage: quality-gate hosted-vitest COMMIT ABSOLUTE_OUTPUT")
                }
                let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                try withInterruptibleGate(root: root) { gate, complete in
                    try gate.hostedVitest(
                        revision: arguments[1], output: URL(fileURLWithPath: arguments[2]),
                        complete: complete)
                }
                return
            }
            if arguments.first == "push" {
                let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                let options = Array(arguments.dropFirst())
                if options.first == "prepare" {
                    try withInterruptibleGate(root: root) { gate, complete in
                        try gate.run(options, completePreparation: complete)
                    }
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

    private static func withInterruptibleGate(
        root: URL, operation: (PushGate, PushGate.CompletePreparation) throws -> Void
    ) throws {
        let queue = kqueue()
        guard queue >= 0 else { throw QualityFailure("Cannot monitor prepare interruption") }
        defer { close(queue) }
        guard fcntl(queue, F_SETFD, FD_CLOEXEC) == 0 else {
            throw QualityFailure("Cannot isolate the signal queue")
        }
        let signals = [SIGINT, SIGTERM]
        let changes = signals.map {
            kevent(
                ident: UInt($0), filter: Int16(EVFILT_SIGNAL), flags: UInt16(EV_ADD),
                fflags: 0, data: 0, udata: nil)
        }
        guard kevent(queue, changes, Int32(changes.count), nil, 0, nil) == 0 else {
            throw QualityFailure("Cannot register prepare interruption")
        }
        // A caught handler returns to the default disposition in exec'd children.
        let previous = signals.map { signal($0) { _ in } }
        defer {
            for (number, disposition) in zip(signals, previous) { signal(number, disposition) }
        }
        // All gate calls are serial. Read pending signals from the kernel directly, including at
        // publication, so a delayed asynchronous notification cannot approve an interrupted run.
        var cancelled = false
        func interrupted() -> Bool {
            if cancelled { return true }
            var event = kevent()
            var immediate = timespec()
            var count: Int32
            repeat {
                count = kevent(queue, nil, 0, &event, 1, &immediate)
            } while count < 0 && errno == EINTR
            cancelled = count != 0
            return cancelled
        }
        let gate = PushGate(root: root) { command, log, timeout in
            try command.run(log: log, timeout: timeout, interrupted: interrupted)
        }
        try operation(gate) { publish in
            // No child is running during receipt operations. Restore synchronous termination
            // before polling prior signals: an interrupt before the atomic rename now prevents it.
            let handlers = signals.map { signal($0, SIG_DFL) }
            defer {
                for (number, handler) in zip(signals, handlers) { signal(number, handler) }
            }
            guard !interrupted() else { throw QualityFailure("Push preparation interrupted") }
            try publish()
        }
    }
}
