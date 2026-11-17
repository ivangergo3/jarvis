import Darwin
import Foundation

public struct Command: Sendable {
    public var executable: String
    public var arguments: [String]
    public var directory: URL
    public var environment: [String: String]?

    public init(
        _ executable: String, _ arguments: [String], directory: URL,
        environment: [String: String]? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.directory = directory
        self.environment = environment
    }

    /// Blocking command execution belongs only in this CLI/test utility, never app UI work.
    /// Foundation owns launch/reaping; the Darwin boundary is limited to checking/killing
    /// the child's isolated process group so timeouts also release descendant test processes.
    public func run(log: URL, timeout: TimeInterval) throws -> Int32 {
        guard timeout > 0 else { throw QualityFailure("Command timeout must be positive") }
        guard FileManager.default.createFile(atPath: log.path, contents: nil) else {
            throw QualityFailure("Cannot create command log")
        }
        let output = try FileHandle(forWritingTo: log)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = output
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        let pid = process.processIdentifier
        // Do not assume an isolated group, and never signal our own process group.
        let group = getpgid(pid)
        // A very short command can already have been reaped before this check.
        let alreadyExited = group == -1 && errno == ESRCH
        if process.isRunning && group != pid && !alreadyExited {
            _ = kill(pid, SIGKILL)
            process.waitUntilExit()
            throw QualityFailure("Foundation did not create an isolated child process group")
        }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            if process.isRunning {
                _ = kill(getpgid(pid) == pid ? -pid : pid, SIGKILL)
            }
            process.waitUntilExit()
            throw QualityFailure("Test command exceeded its time limit")
        }
        process.waitUntilExit()
        return process.terminationReason == .uncaughtSignal
            ? -process.terminationStatus : process.terminationStatus
    }
}
