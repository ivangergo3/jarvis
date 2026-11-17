import Foundation

/// Offline evidence classification, not a portable CPU pass/fail gate or an attestation.
public enum PerformanceAudit {
    struct Identity: Decodable {
        let revision: String
        let trackedTreeDirty: Bool?
        let untrackedAppSources: Bool?
        let binarySHA256: String
        let architecture: String
        let toolchain: String
    }
    struct Distribution: Decodable { let samples: [Double] }
    struct Series: Decodable {
        let name: String
        let iterationsPerSample: Int
        let warmupRepetitions: Int
        let milliseconds: Distribution
        let checksum: Double
    }
    struct Phase: Decodable {
        let name: String
        let nodes: Int
        let repetition: Int
        let elapsedSeconds: Double
        let cpuPercentOfOneCore: Double
        let mainThreadCPUPercentOfOneCore: Double
        let residentStart: Double
        let residentEnd: Double
        let residentSamples: [Double]
        let work: [String: Int]
        let foregroundThroughout: Bool
        let selectionPreserved: Bool
        let loopIterations: Int?
        let targetHz: Double?
        let unoccludedThroughout: Bool?
        let powerStateStable: Bool?
        let lowPowerMode: Bool?
    }
    struct Raw: Decodable {
        let schema: Int?
        let measurementProtocol: String?
        let buildIdentity: Identity?
        let revision: String
        let hardware: String
        let architecture: String
        let toolchain: String
        let os: String
        let buildMode: String
        let fixture: [String: Int]
        let animationRequested: Bool?
        let reduceMotion: Bool?
        let windowWidth: Double?
        let windowHeight: Double?
        let backingScale: Double?
        let displayMaximumHz: Int?
        let phases: [Phase]?
        let series: [Series]?
        let error: String?
    }
    struct Policy: Decodable {
        let schema: Int
        let id: String
        let agreement: String
        let hardware: String
        let architecture: String
        let windowWidth: Double
        let windowHeight: Double
        let backingScale: Double
        let displayMaximumHz: Int
        let idle20CPU: Double
        let hover20CPU: Double
        let hover100CPU: Double
    }
    public struct Observation: Encodable {
        public let workload: String
        public let nodes: Int?
        public let repetition: Int?
        public let eligible: Bool
        public let reasons: [String]
        public let measuredCPU: Double?
        public let warningCPU: Double?
        public let exceedsWarning: Bool?
        public let deliveredHz: Double?
        public let residentGrowthBytes: Double?
        public let minimumMilliseconds: Double?
        public let medianMilliseconds: Double?
        public let p95Milliseconds: Double?
        public let maximumMilliseconds: Double?
    }
    public struct Result: Encodable {
        public let schema = 1
        public let revision: String
        public let policy: String
        public let conclusion: String
        public let identityIssues: [String]
        public let observations: [Observation]
        public let comparison: String
        public let comparisonIssues: [String]
        public let limitations: [String]
    }

    static func read<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let limit = 8 * 1_024 * 1_024
        guard let data = try file.read(upToCount: limit + 1), data.count <= limit else {
            throw QualityFailure("Performance evidence exceeds the 8 MiB limit")
        }
        do { return try JSONDecoder().decode(type, from: data) } catch {
            throw QualityFailure("Malformed performance evidence or policy")
        }
    }
    private static func finite(_ values: [Double]) -> Bool {
        values.allSatisfy { $0.isFinite && $0 >= 0 }
    }
    private static func hex(_ value: String, length: Int) -> Bool {
        value.count == length && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
    private static func identityIssues(_ raw: Raw) -> [String] {
        var issues: [String] = []
        if raw.schema != 2 { issues.append("Legacy or unsupported provenance schema") }
        if raw.measurementProtocol != (raw.phases == nil ? "computation-v2" : "ui-v2") {
            issues.append("Unsupported measurement protocol")
        }
        guard let identity = raw.buildIdentity else { return issues + ["Missing build identity"] }
        if !hex(identity.revision, length: 40) || identity.revision != raw.revision {
            issues.append("Missing or inconsistent built revision")
        }
        if !hex(identity.binarySHA256, length: 64) { issues.append("Missing executable digest") }
        if identity.trackedTreeDirty != false || identity.untrackedAppSources != false {
            issues.append("Built source cleanliness is dirty or unknown")
        }
        if identity.architecture != raw.architecture || identity.toolchain != raw.toolchain
            || [raw.hardware, raw.architecture, raw.toolchain, raw.os].contains(where: {
                $0.isEmpty || $0 == "unknown"
            })
        {
            issues.append("Missing or inconsistent environment identity")
        }
        if !["release", "release-instrumented"].contains(raw.buildMode) {
            issues.append("Evidence is not a Release build")
        }
        if raw.error != nil { issues.append("The measurement run failed") }
        return issues
    }
    private static func check(_ raw: Raw) throws {
        guard (raw.phases == nil) != (raw.series == nil),
            raw.fixture["projects"] == 5, raw.fixture["chats"] == 125,
            raw.fixture["eventsPerChat"] == 1_002, raw.fixture["logBytes", default: 0] > 0
        else { throw QualityFailure("Missing or ambiguous synthetic performance workload") }
        if let phases = raw.phases {
            guard !phases.isEmpty, phases.count <= 1_000 else {
                throw QualityFailure("Missing or excessive phases")
            }
            for phase in phases {
                guard phase.nodes >= 0, phase.repetition >= 0, phase.elapsedSeconds > 0,
                    finite(
                        [
                            phase.elapsedSeconds, phase.cpuPercentOfOneCore,
                            phase.mainThreadCPUPercentOfOneCore, phase.residentStart,
                            phase.residentEnd,
                        ] + phase.residentSamples),
                    phase.work.values.allSatisfy({ $0 >= 0 && $0 <= 100_000_000 }),
                    phase.loopIterations.map({ $0 >= 0 && $0 <= 10_000_000 }) != false,
                    phase.targetHz.map({ $0 > 0 && $0.isFinite }) != false
                else { throw QualityFailure("Invalid phase measurements or work counters") }
            }
        }
        if let series = raw.series {
            guard !series.isEmpty, Set(series.map(\.name)).count == series.count else {
                throw QualityFailure("Missing or duplicate computation series")
            }
            for item in series {
                guard item.iterationsPerSample > 0, item.warmupRepetitions > 0,
                    !item.milliseconds.samples.isEmpty, finite(item.milliseconds.samples),
                    item.checksum.isFinite, item.checksum >= 0
                else { throw QualityFailure("Invalid computation measurements") }
            }
        }
    }
    private static func scope(_ raw: Raw, _ policy: Policy) -> Bool {
        raw.hardware == policy.hardware && raw.architecture == policy.architecture
            && raw.windowWidth == policy.windowWidth && raw.windowHeight == policy.windowHeight
            && raw.backingScale == policy.backingScale
            && raw.displayMaximumHz == policy.displayMaximumHz
            && raw.buildMode == "release-instrumented" && raw.animationRequested == true
            && raw.reduceMotion == false
    }
    private static func observations(_ raw: Raw, _ policy: Policy, issues: [String])
        -> [Observation]
    {
        var result: [Observation] = []
        for phase in raw.phases ?? [] {
            var reasons = issues
            let scriptedHover = ["hover-state", "bounded-soak"].contains(phase.name)
            if !["idle", "hover-state", "bounded-soak", "manual-pointer"].contains(phase.name)
                || phase.targetHz != (scriptedHover ? 60 : 20)
            {
                reasons.append("Unknown workload or changed requested cadence")
            }
            if !phase.foregroundThroughout || phase.unoccludedThroughout != true {
                reasons.append("Background, occluded or unknown visibility")
            }
            if phase.powerStateStable != true || phase.lowPowerMode != false {
                reasons.append("Changed or unknown power conditions")
            }
            if !phase.selectionPreserved { reasons.append("Selection changed during measurement") }
            let rate = phase.loopIterations.map { Double($0) / phase.elapsedSeconds }
            if let rate, let target = phase.targetHz {
                if rate < target * 0.8 {
                    reasons.append("Delivered cadence below 80% of requested workload")
                }
            } else {
                reasons.append("Delivered workload is unknown")
            }
            if phase.name == "manual-pointer" {
                reasons.append("Human-controlled pointer input is descriptive only")
            }
            let forbidden = [
                "dashboardPublication", "conversationPublication", "connectorRebuild",
                "dashboardBody", "conversationBody", "graphLayout", "cardFactory",
                "hoverDestinationBody", "hoverTopologyBody",
            ]
            if forbidden.contains(where: { phase.work[$0] != 0 }) {
                reasons.append("Unexpected or missing broad-work counters")
            }
            if phase.name == "idle", phase.work["physicalHoverCallback"] != 0 {
                reasons.append("Idle phase contains pointer activity")
            }
            if ["hover-state", "bounded-soak"].contains(phase.name),
                let loops = phase.loopIterations
            {
                if phase.work["physicalHoverCallback"] != 0
                    || phase.work["hoverPublication"] != loops
                    || phase.work["nativeTopologyUpdate"] != loops
                    || !(1...(loops * 2 + 1)).contains(
                        phase.work["nativeDestinationUpdate", default: 0])
                {
                    reasons.append("Requested hover work was changed or not delivered")
                }
            }
            let eligible = reasons.isEmpty
            var budget: Double?
            if eligible && scope(raw, policy) {
                if phase.name == "idle" && phase.nodes == 20 { budget = policy.idle20CPU }
                if phase.name == "hover-state" && phase.nodes == 20 { budget = policy.hover20CPU }
                if phase.name == "hover-state" && phase.nodes == 100 { budget = policy.hover100CPU }
            }
            result.append(
                Observation(
                    workload: phase.name, nodes: phase.nodes, repetition: phase.repetition,
                    eligible: eligible, reasons: reasons, measuredCPU: phase.cpuPercentOfOneCore,
                    warningCPU: budget,
                    exceedsWarning: budget.map { phase.cpuPercentOfOneCore > $0 },
                    deliveredHz: rate, residentGrowthBytes: phase.residentEnd - phase.residentStart,
                    minimumMilliseconds: nil, medianMilliseconds: nil, p95Milliseconds: nil,
                    maximumMilliseconds: nil))
        }
        for series in raw.series ?? [] {
            let sorted = series.milliseconds.samples.sorted()
            var reasons = issues
            if sorted.count < 7 { reasons.append("Fewer than seven computation repetitions") }
            result.append(
                Observation(
                    workload: series.name, nodes: nil, repetition: nil,
                    eligible: reasons.isEmpty, reasons: reasons, measuredCPU: nil, warningCPU: nil,
                    exceedsWarning: nil,
                    deliveredHz: nil, residentGrowthBytes: nil, minimumMilliseconds: sorted[0],
                    medianMilliseconds: sorted.count.isMultiple(of: 2)
                        ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
                        : sorted[sorted.count / 2],
                    p95Milliseconds: sorted[max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)],
                    maximumMilliseconds: sorted.last))
        }
        return result
    }

    static func evaluate(_ raw: Raw, baseline: Raw?, policy: Policy) throws -> Result {
        try check(raw)
        guard policy.schema == 1, !policy.id.isEmpty, !policy.agreement.isEmpty,
            finite([policy.idle20CPU, policy.hover20CPU, policy.hover100CPU])
        else {
            throw QualityFailure("Invalid or unapproved performance warning policy")
        }
        let issues = identityIssues(raw)
        let rows = observations(raw, policy, issues: issues)
        var comparisonIssues: [String] = []
        if let baseline {
            try check(baseline)
            comparisonIssues += identityIssues(baseline) + issues
            if raw.measurementProtocol == nil
                || raw.measurementProtocol != baseline.measurementProtocol
                || raw.hardware != baseline.hardware || raw.architecture != baseline.architecture
                || raw.toolchain != baseline.toolchain || raw.os != baseline.os
                || raw.buildMode != baseline.buildMode
                || raw.fixture.filter({ $0.key != "clockSeconds" })
                    != baseline.fixture.filter({ $0.key != "clockSeconds" })
                || raw.windowWidth != baseline.windowWidth
                || raw.windowHeight != baseline.windowHeight
                || raw.backingScale != baseline.backingScale
                || raw.displayMaximumHz != baseline.displayMaximumHz
                || raw.animationRequested != baseline.animationRequested
                || raw.reduceMotion != baseline.reduceMotion
            {
                comparisonIssues.append("Configuration or measurement protocol differs")
            }
            let previous = observations(baseline, policy, issues: identityIssues(baseline))
            for (current, old) in zip(raw.series ?? [], baseline.series ?? []) {
                if current.iterationsPerSample != old.iterationsPerSample
                    || current.warmupRepetitions != old.warmupRepetitions
                    || current.checksum != old.checksum
                    || current.milliseconds.samples.count != old.milliseconds.samples.count
                {
                    comparisonIssues.append("Computation work or repetitions differ")
                }
            }
            if rows.count != previous.count {
                comparisonIssues.append("Workload inventory differs")
            }
            for (current, old) in zip(rows, previous) {
                if !current.eligible || !old.eligible || current.workload != old.workload
                    || current.nodes != old.nodes || current.repetition != old.repetition
                {
                    comparisonIssues.append("Missing, ineligible or different workload")
                }
                if let rate = current.deliveredHz, let before = old.deliveredHz,
                    abs(rate - before) > max(rate, before) * 0.1
                {
                    comparisonIssues.append("Delivered input rates differ by more than 10%")
                }
            }
        }
        let warnings = rows.contains { $0.exceedsWarning == true }
        let conclusion =
            issues.isEmpty && rows.allSatisfy(\.eligible)
            ? (warnings
                ? "investigate"
                : rows.contains(where: { $0.warningCPU != nil })
                    ? "within-warning-budgets" : "reported-without-applicable-budget")
            : "inconclusive"
        return Result(
            revision: raw.revision, policy: policy.id, conclusion: conclusion,
            identityIssues: issues,
            observations: rows,
            comparison: baseline == nil
                ? "not-requested" : comparisonIssues.isEmpty ? "comparable" : "incomparable",
            comparisonIssues: Array(Set(comparisonIssues)).sorted(),
            limitations: [
                "CPU warnings are owner-scoped investigation thresholds, not CI CPU gates.",
                "Main-entry/body and cadence metrics do not certify OS launch or input-to-photon latency.",
                "Source stamps and executable digests identify artifacts; they are not cryptographic attestations.",
                "OS caches and competing system load remain uncontrolled; raw inputs are retained by the caller.",
                "Eligibility applies only to the listed workloads; a partial report cannot establish full feature coverage.",
            ])
    }

    public static func run(report: URL, baseline: URL?, policy: URL, output: URL) throws -> Result {
        let destination = output.appendingPathComponent("performance-audit.json")
        guard
            !([report, policy] + (baseline.map { [$0] } ?? [])).contains(where: {
                $0.resolvingSymlinksInPath().standardizedFileURL
                    == destination.resolvingSymlinksInPath().standardizedFileURL
            })
        else { throw QualityFailure("Audit output must not overwrite an input") }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        // Invalidate any earlier success before attempting to read a new report.
        try Diagnostics.writeJSON(
            ["conclusion": "invalid", "reason": "Audit did not complete"], to: destination)
        let raw = try read(Raw.self, at: report)
        let previous = try baseline.map { try read(Raw.self, at: $0) }
        let result = try evaluate(raw, baseline: previous, policy: read(Policy.self, at: policy))
        try Diagnostics.writeJSON(result, to: destination)
        return result
    }
}
