import Darwin
import Foundation

/// Opt-in, own-process counters for synthetic release measurements only.
struct PerformanceResources: Codable, Sendable {
    let cpuSeconds: Double
    let residentBytes: UInt64
    let callingThreadCPUSeconds: Double

    static func capture() throws -> Self {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else {
            throw PerformanceFailure("getrusage failed")
        }
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        // Scoped Mach C-ABI interoperability: only our task, no pointer escapes or
        // Sendable bypass. task_info requires an integer buffer for this typed struct.
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw PerformanceFailure("task_info failed") }
        var thread = thread_basic_info()
        var threadCount = mach_msg_type_number_t(
            MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
        let threadResult = withUnsafeMutablePointer(to: &thread) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(threadCount)) {
                thread_info(
                    pthread_mach_thread_np(pthread_self()), thread_flavor_t(THREAD_BASIC_INFO), $0,
                    &threadCount)
            }
        }
        guard threadResult == KERN_SUCCESS else { throw PerformanceFailure("thread_info failed") }
        let threadCPU =
            Double(thread.user_time.seconds + thread.system_time.seconds)
            + Double(thread.user_time.microseconds + thread.system_time.microseconds) / 1_000_000
        let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
        let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        return Self(
            cpuSeconds: user + system, residentBytes: UInt64(info.resident_size),
            callingThreadCPUSeconds: threadCPU)
    }

    static func hardwareModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0, size < 256 else {
            return "unavailable"
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return "unavailable" }
        return String(
            decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

struct PerformanceFailure: Error, LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct PerformanceDistribution: Codable, Sendable {
    let samples: [Double]
    let minimum: Double
    let median: Double
    let p95: Double
    let maximum: Double

    init(_ samples: [Double]) throws {
        guard !samples.isEmpty, samples.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw PerformanceFailure("Missing, negative or nonfinite measurement")
        }
        let sorted = samples.sorted()
        self.samples = samples
        minimum = sorted[0]
        maximum = sorted[sorted.count - 1]
        median =
            sorted.count.isMultiple(of: 2)
            ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            : sorted[sorted.count / 2]
        p95 = sorted[max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
    }
}
