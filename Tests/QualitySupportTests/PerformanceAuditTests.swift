import Foundation
import Testing

@testable import QualitySupport

@Suite("Offline performance evidence")
struct PerformanceAuditTests {
    private func report() -> [String: Any] {
        let revision = String(repeating: "a", count: 40)
        var work = Dictionary(
            uniqueKeysWithValues: [
                "dashboardPublication", "conversationPublication", "connectorRebuild",
                "dashboardBody", "conversationBody", "graphLayout", "cardFactory",
                "hoverDestinationBody", "hoverTopologyBody", "physicalHoverCallback",
            ].map { ($0, 0) })
        work.merge([
            "hoverPublication": 600, "nativeTopologyUpdate": 600, "nativeDestinationUpdate": 1199,
        ]) { _, new in new }
        return [
            "schema": 2, "measurementProtocol": "ui-v2", "revision": revision,
            "hardware": "Mac15,13", "architecture": "arm64", "toolchain": "Swift fixture",
            "os": "Fixture OS",
            "buildMode": "release-instrumented", "animationRequested": true, "reduceMotion": false,
            "windowWidth": 1500, "windowHeight": 940, "backingScale": 2, "displayMaximumHz": 60,
            "buildIdentity": [
                "revision": revision, "trackedTreeDirty": false, "untrackedAppSources": false,
                "binarySHA256": String(repeating: "b", count: 64), "architecture": "arm64",
                "toolchain": "Swift fixture",
            ],
            "fixture": ["projects": 5, "chats": 125, "eventsPerChat": 1002, "logBytes": 10000],
            "phases": [
                [
                    "name": "hover-state", "nodes": 20, "repetition": 1, "elapsedSeconds": 10,
                    "cpuPercentOfOneCore": 13, "mainThreadCPUPercentOfOneCore": 10,
                    "residentStart": 100, "residentEnd": 120, "residentSamples": [100, 120],
                    "work": work, "foregroundThroughout": true, "selectionPreserved": true,
                    "loopIterations": 600, "targetHz": 60, "unoccludedThroughout": true,
                    "powerStateStable": true, "lowPowerMode": false,
                ]
            ],
        ]
    }

    private func decode(_ value: [String: Any]) throws -> PerformanceAudit.Raw {
        try JSONDecoder().decode(
            PerformanceAudit.Raw.self, from: JSONSerialization.data(withJSONObject: value))
    }

    private func policy() throws -> PerformanceAudit.Policy {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try PerformanceAudit.read(
            PerformanceAudit.Policy.self,
            at: root.appendingPathComponent("Tools/performance-budgets.json"))
    }

    @Test func ownerWarningsRemainAdvisoryAndMachineScoped() throws {
        let policy = try policy()
        #expect(policy.idle20CPU == 5 && policy.hover20CPU == 12 && policy.hover100CPU == 20)
        let raw = try decode(report())
        let result = try PerformanceAudit.evaluate(raw, baseline: raw, policy: policy)
        #expect(result.conclusion == "investigate")
        #expect(result.comparison == "comparable")
        #expect(result.observations.first?.residentGrowthBytes == 20)
        var other = report()
        other["hardware"] = "Another Mac"
        let unscoped = try PerformanceAudit.evaluate(decode(other), baseline: nil, policy: policy)
        #expect(unscoped.conclusion == "reported-without-applicable-budget")
        #expect(unscoped.observations.first?.warningCPU == nil)
    }

    @Test func invalidConditionsRemainVisibleAndCannotPass() throws {
        for key in [
            "foregroundThroughout", "selectionPreserved", "unoccludedThroughout",
            "powerStateStable", "loopIterations",
        ] {
            var value = report()
            var phases = value["phases"] as? [[String: Any]] ?? []
            phases[0][key] = key == "loopIterations" ? 200 : false
            value["phases"] = phases
            let result = try PerformanceAudit.evaluate(
                decode(value), baseline: nil, policy: policy())
            #expect(result.conclusion == "inconclusive")
            #expect(result.observations.count == 1)
            #expect(result.observations.first?.measuredCPU == 13)
            #expect(result.observations.first?.warningCPU == nil)
        }
        var value = report()
        value["schema"] = 1
        value.removeValue(forKey: "buildIdentity")
        #expect(
            try PerformanceAudit.evaluate(decode(value), baseline: nil, policy: policy()).conclusion
                == "inconclusive")
    }

    @Test func changedConfigurationAndWorkCannotBeCompared() throws {
        let original = try decode(report())
        for (key, changed) in [
            ("os", "Different OS"), ("hardware", "Different Mac"), ("buildMode", "debug"),
            ("measurementProtocol", "invented"),
        ] {
            var value = report()
            value[key] = changed
            #expect(
                try PerformanceAudit.evaluate(decode(value), baseline: original, policy: policy())
                    .comparison == "incomparable")
        }
        var value = report()
        var phases = value["phases"] as? [[String: Any]] ?? []
        phases[0]["work"] = ["hoverPublication": 600]
        value["phases"] = phases
        #expect(
            try PerformanceAudit.evaluate(decode(value), baseline: original, policy: policy())
                .conclusion == "inconclusive")
    }

    @Test func dirtyFailedAndMalformedMeasurementsCannotPass() throws {
        var value = report()
        var identity = value["buildIdentity"] as? [String: Any] ?? [:]
        identity["trackedTreeDirty"] = true
        value["buildIdentity"] = identity
        #expect(
            try PerformanceAudit.evaluate(decode(value), baseline: nil, policy: policy()).conclusion
                == "inconclusive")
        value = report()
        value["error"] = "Synthetic failure"
        #expect(
            try PerformanceAudit.evaluate(decode(value), baseline: nil, policy: policy()).conclusion
                == "inconclusive")
        for (key, invalid) in [
            ("elapsedSeconds", 0), ("cpuPercentOfOneCore", -1), ("loopIterations", -1),
        ] {
            value = report()
            var phases = value["phases"] as? [[String: Any]] ?? []
            phases[0][key] = invalid
            value["phases"] = phases
            #expect(throws: (any Error).self) {
                try PerformanceAudit.evaluate(decode(value), baseline: nil, policy: policy())
            }
        }
    }

    @Test func computationStatisticsUseSamplesAndCompareWorkUnits() throws {
        var value = report()
        value.removeValue(forKey: "phases")
        value["measurementProtocol"] = "computation-v2"
        value["buildMode"] = "release"
        var series: [String: Any] = [
            "name": "graph-20", "iterationsPerSample": 200, "warmupRepetitions": 1,
            "checksum": 100, "milliseconds": ["samples": [7, 1, 5, 3, 6, 2, 4], "median": 999],
        ]
        value["series"] = [series]
        let baseline = try decode(value)
        let result = try PerformanceAudit.evaluate(baseline, baseline: nil, policy: policy())
        #expect(result.observations.first?.medianMilliseconds == 4)
        #expect(result.observations.first?.p95Milliseconds == 7)
        series["iterationsPerSample"] = 100
        value["series"] = [series]
        #expect(
            try PerformanceAudit.evaluate(decode(value), baseline: baseline, policy: policy())
                .comparison == "incomparable")
    }

    @Test func failureInvalidatesOldSuccessWithoutTouchingInputs() throws {
        let temporary = try TemporaryDirectory(prefix: "performance-audit-")
        let input = temporary.url.appendingPathComponent("raw.json")
        let policyURL = temporary.url.appendingPathComponent("policy.json")
        try Data("malformed".utf8).write(to: input)
        try Data("{}".utf8).write(to: policyURL)
        let destination = temporary.url.appendingPathComponent("performance-audit.json")
        try Data("old success".utf8).write(to: destination)
        #expect(throws: (any Error).self) {
            try PerformanceAudit.run(
                report: input, baseline: nil, policy: policyURL, output: temporary.url)
        }
        #expect(try String(contentsOf: input, encoding: .utf8) == "malformed")
        #expect(try String(contentsOf: destination, encoding: .utf8).contains("invalid"))
        let before = try Data(contentsOf: destination)
        #expect(throws: (any Error).self) {
            try PerformanceAudit.run(
                report: destination, baseline: nil, policy: policyURL, output: temporary.url)
        }
        #expect(try Data(contentsOf: destination) == before)
        try Data(repeating: 32, count: 8 * 1024 * 1024 + 1).write(to: input)
        #expect(throws: (any Error).self) {
            try PerformanceAudit.read(PerformanceAudit.Raw.self, at: input)
        }
    }
}
