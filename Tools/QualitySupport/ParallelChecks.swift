import Darwin
import Foundation

/// CLI-only. Own the lane roots so interruption can stop their nested SwiftPM processes.
public enum ParallelChecks {
    public static func run(gate: String, arguments: [String]) throws {
        let interrupted = DispatchSemaphore(value: 0)
        let signals = [SIGINT, SIGTERM, SIGHUP].map { number in
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number)
            source.setEventHandler { interrupted.signal() }
            source.activate()
            return source
        }
        defer { for source in signals { source.cancel() } }

        var running: [Process] = []
        do {
            for batch in [["core", "hover"], ["release"]] {
                for lane in batch {
                    let child = Process()
                    child.executableURL = URL(fileURLWithPath: "/bin/bash")
                    child.arguments = ["scripts/check-lane.sh", lane, gate] + arguments
                    try child.run()
                    running.append(child)
                }
                while running.contains(where: \.isRunning) {
                    if interrupted.wait(timeout: .now() + .milliseconds(100)) == .success {
                        throw QualityFailure("Local verification interrupted")
                    }
                }
                guard interrupted.wait(timeout: .now()) == .timedOut else {
                    throw QualityFailure("Local verification interrupted")
                }
                for (lane, child) in zip(batch, running) {
                    child.waitUntilExit()
                    guard child.terminationReason == .exit, child.terminationStatus == 0 else {
                        throw QualityFailure("Local verification failed in the " + lane + " lane")
                    }
                }
                running.removeAll()
            }
        } catch {
            var cleanupFailure: Error?
            for child in running where child.isRunning {
                do {
                    try OwnedProcessTree.terminate(child.processIdentifier)
                    child.waitUntilExit()
                } catch {
                    cleanupFailure = error
                }
            }
            throw cleanupFailure ?? error
        }
    }
}
