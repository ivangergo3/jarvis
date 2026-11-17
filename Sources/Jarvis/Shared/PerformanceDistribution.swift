import Foundation

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
