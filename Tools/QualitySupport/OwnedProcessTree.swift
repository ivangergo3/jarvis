import Darwin
import Foundation

public struct CommandCleanupFailure: Error, LocalizedError {
    public let detail: String
    public var errorDescription: String? {
        "Command cleanup could not be confirmed; retain its workspace. " + detail
    }
}

/// CLI-only SDK interop: inspect only descendants of the Foundation-owned child.
/// Freeze parents before walking children, keeping ordinary supervisors from spawning/reaping.
enum OwnedProcessTree {
    struct Node {
        let pid: pid_t
        let seconds: UInt64
        let microseconds: UInt64
        func matches(_ info: proc_bsdinfo) -> Bool {
            info.pbi_pid == UInt32(pid) && info.pbi_start_tvsec == seconds
                && info.pbi_start_tvusec == microseconds
        }
    }

    static func inspect(_ pid: pid_t) throws -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        // For PROC_PIDTBSDINFO a nonzero argument includes exited, unreaped PIDs.
        let includeZombies: UInt64 = 1
        // Synchronous C call; the typed buffer's lifetime and byte count are scoped to this call.
        let size = withUnsafeMutableBytes(of: &info) {
            proc_pidinfo(pid, PROC_PIDTBSDINFO, includeZombies, $0.baseAddress, Int32($0.count))
        }
        if size == MemoryLayout<proc_bsdinfo>.stride { return info }
        if kill(pid, 0) == -1 && errno == ESRCH { return nil }
        throw QualityFailure("Cannot inspect an owned command process")
    }

    static func children(_ pid: pid_t) throws -> [pid_t] {
        var capacity = 16
        while capacity <= 65_536 {
            var buffer = [pid_t](repeating: 0, count: capacity)
            errno = 0
            // libproc returns a PID count, not a byte count; retry a full buffer.
            let count = buffer.withUnsafeMutableBytes {
                proc_listchildpids(pid, $0.baseAddress, Int32($0.count))
            }
            guard count >= 0, count != 0 || errno == 0 else {
                throw QualityFailure("Cannot enumerate owned command descendants")
            }
            if count < capacity { return Array(buffer.prefix(Int(count))).filter { $0 > 0 } }
            capacity *= 2
        }
        throw QualityFailure("Owned command process tree exceeds the enumeration bound")
    }

    static func killMatching(_ node: Node) throws {
        guard let info = try inspect(node.pid), node.matches(info) else { return }
        if kill(node.pid, SIGKILL) != 0 && errno != ESRCH {
            throw QualityFailure("Cannot terminate an owned command descendant")
        }
    }

    static func confirmExit(_ node: Node, before deadline: ContinuousClock.Instant) throws {
        let clock = ContinuousClock()
        while let info = try inspect(node.pid), node.matches(info), info.pbi_status != UInt32(SZOMB)
        {
            guard clock.now < deadline else {
                throw QualityFailure("Owned command termination was not observed")
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    static func terminate(_ root: pid_t) throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        var captured: [Node] = []
        var pending: [(pid_t, pid_t)] = [(root, getpid())]
        var visited = Set<pid_t>()
        do {
            while let (pid, parent) = pending.popLast() {
                guard pid > 1, pid != getpid(), visited.insert(pid).inserted,
                    captured.count < 65_536, clock.now < deadline,
                    let info = try inspect(pid), info.pbi_ppid == UInt32(parent)
                else { throw QualityFailure("Owned command ancestry changed during cleanup") }
                let node = Node(
                    pid: pid, seconds: info.pbi_start_tvsec, microseconds: info.pbi_start_tvusec)
                captured.append(node)
                guard info.pbi_status != UInt32(SZOMB) else {
                    throw QualityFailure(
                        "Supervisor exited before descendant ownership was captured")
                }
                guard kill(pid, SIGSTOP) == 0 else {
                    throw QualityFailure("Cannot freeze an owned command process")
                }
                while true {
                    guard clock.now < deadline, let stopped = try inspect(pid),
                        node.matches(stopped),
                        stopped.pbi_ppid == UInt32(parent)
                    else { throw QualityFailure("Owned command identity changed while freezing") }
                    guard stopped.pbi_status != UInt32(SZOMB) else {
                        throw QualityFailure(
                            "Supervisor exited while descendant ownership was being captured")
                    }
                    if stopped.pbi_status == UInt32(SSTOP) { break }
                    Thread.sleep(forTimeInterval: 0.01)
                }
                pending += try children(pid).map { ($0, pid) }
            }
            for node in captured.reversed() { try killMatching(node) }
            for node in captured { try confirmExit(node, before: deadline) }
        } catch {
            var partial = false
            for node in captured.reversed() {
                do { try killMatching(node) } catch { partial = true }
            }
            throw CommandCleanupFailure(
                detail: error.localizedDescription
                    + (partial ? "; some descendants remain uncertain" : ""))
        }
    }
}
