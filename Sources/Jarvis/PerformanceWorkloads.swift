import Foundation
import JarvisDomain

struct PerformanceSeries: Encodable, Sendable {
    let name: String
    let iterationsPerSample: Int
    let warmupRepetitions = 1
    let milliseconds: PerformanceDistribution
    let checksum: Double
}

/// CPU workloads use an actor executor; they never block the app's main actor.
private actor PerformanceComputation {
    func graph(nodes: Int, repetitions: Int) throws -> Double {
        var checksum = 0.0
        for iteration in 0..<repetitions {
            let layout = TeamGraphLayout(
                count: nodes, viewport: CGSize(width: 1_280 + iteration % 2, height: 720))
            let routes = layout.connections
            guard layout.nodes.count == nodes, routes.count == nodes else {
                throw PerformanceFailure("Graph lost nodes/routes")
            }
            for (node, route) in zip(layout.nodes, routes) {
                let edge =
                    node.x
                    + (node.x < layout.center.x ? layout.cardWidth / 2 : -layout.cardWidth / 2)
                guard route.destination == CGPoint(x: edge, y: node.y),
                    route.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
                else {
                    throw PerformanceFailure("Graph route endpoint/finite-coordinate check failed")
                }
                checksum += Double(route.destination.x + route.destination.y)
            }
        }
        return checksum
    }

    func protocolFrames(repetitions: Int) throws -> Double {
        let data = Data(
            (0..<2_000).map { "{\"id\":\($0),\"text\":\"synthetic 🦾\"}\n" }.joined().utf8)
        var checksum = 0
        for _ in 0..<repetitions {
            var parser = ProtocolLines()
            var records: [WireValue] = []
            for start in stride(from: 0, to: data.count, by: 16_384) {
                records += try parser.feed(
                    data.subdata(in: start..<min(data.count, start + 16_384)))
            }
            guard records.count == 2_000,
                records.enumerated().allSatisfy({ $0.element["id"] == .number($0.offset) })
            else {
                throw PerformanceFailure("Framing lost or reordered records")
            }
            checksum += records.count
        }
        return Double(checksum)
    }
}

@MainActor enum PerformanceWorkloads {
    struct Report: Encodable {
        let revision: String
        let hardware: String
        let architecture: String
        let toolchain: String
        let os: String
        let buildMode = "release"
        let cacheState =
            "OS cache uncontrolled; fresh adapter and warmed adapter measured separately"
        let fixture: [String: Int]
        let series: [PerformanceSeries]
    }

    static func run(
        home: URL, output: URL, revision: String,
        makeSource: @Sendable () -> any WorkspaceSource
    ) async throws {
        #if DEBUG
            throw PerformanceFailure("Performance evidence requires a release build")
        #else
            let fixture = try JSONDecoder().decode(
                [String: Int].self,
                from: Data(contentsOf: home.appendingPathComponent("performance-fixture.json")))
            guard fixture["projects"] == 5, fixture["chats"] == 125 else {
                throw PerformanceFailure("Generate the synthetic performance fixture first")
            }
            let source = makeSource()
            let initial = try await source.read()
            try validate(initial)
            let computation = PerformanceComputation()
            var series: [PerformanceSeries] = []
            for nodes in [0, 1, 4, 20, 100] {
                _ = try await computation.graph(nodes: nodes, repetitions: 200)
                var samples: [Double] = []
                var checksum = 0.0
                for _ in 0..<7 {
                    let start = ProcessInfo.processInfo.systemUptime
                    checksum += try await computation.graph(nodes: nodes, repetitions: 200)
                    samples.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
                }
                series.append(
                    PerformanceSeries(
                        name: "graph-\(nodes)", iterationsPerSample: 200,
                        milliseconds: try PerformanceDistribution(samples), checksum: checksum))
            }
            _ = try await computation.protocolFrames(repetitions: 8)
            var protocolSamples: [Double] = []
            var checksum = 0.0
            for _ in 0..<7 {
                let start = ProcessInfo.processInfo.systemUptime
                checksum += try await computation.protocolFrames(repetitions: 8)
                protocolSamples.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
            }
            series.append(
                PerformanceSeries(
                    name: "protocol-2000-records", iterationsPerSample: 8,
                    milliseconds: try PerformanceDistribution(protocolSamples), checksum: checksum))
            for cached in [false, true] {
                var samples: [Double] = []
                for _ in 0..<7 {
                    let reader = cached ? source : makeSource()
                    let start = ProcessInfo.processInfo.systemUptime
                    let snapshot = try await reader.read()
                    samples.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
                    try validate(snapshot)
                    guard snapshot.hasSameDisplayContent(as: initial) else {
                        throw PerformanceFailure("Cached/fresh reader changed display content")
                    }
                }
                series.append(
                    PerformanceSeries(
                        name: cached ? "workspace-cached" : "workspace-fresh-adapter",
                        iterationsPerSample: 1, milliseconds: try PerformanceDistribution(samples),
                        checksum: Double(initial.missions.count * 7)))
            }
            let report = Report(
                revision: revision, hardware: PerformanceResources.hardwareModel(),
                architecture: Bundle.main.object(
                    forInfoDictionaryKey: "JarvisPerformanceArchitecture") as? String ?? "unknown",
                toolchain: Bundle.main.object(forInfoDictionaryKey: "JarvisPerformanceToolchain")
                    as? String ?? "unknown",
                os: ProcessInfo.processInfo.operatingSystemVersionString, fixture: fixture,
                series: series)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: output, options: .atomic)
        #endif
    }

    private static func validate(_ snapshot: FleetSnapshot) throws {
        guard snapshot.missions.count == 125,
            Set(snapshot.projects.map(\.id)) == Set([0, 1, 4, 20, 100].map { "perf-\($0)" }),
            snapshot.missions.allSatisfy({
                $0.id.hasPrefix("perf-") && $0.task.hasPrefix("Synthetic task for perf-")
            })
        else {
            throw PerformanceFailure(
                "Unexpected workspace content; refusing performance measurement")
        }
    }
}
