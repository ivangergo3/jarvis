import AppKit
import Combine
import Foundation
import JarvisDomain
import SwiftUI

@MainActor final class PerformanceProgress: ObservableObject {
    @Published var stage = "Preparing synthetic performance recording"
    @Published var cursorFinished = false
}

/// Instrumentation does not publish. Enabled only by an explicitly prepared fixture bundle.
@MainActor final class PerformanceSession {
    enum Work: String, Codable, CaseIterable {
        case dashboardBody, conversationBody, graphLayout, cardFactory
        case hoverTopologyBody, hoverDestinationBody, connectorRebuild, nativeDraw
        case dashboardPublication, conversationPublication, hoverPublication
        case physicalHoverCallback
    }
    struct Phase: Codable {
        let name: String
        let nodes: Int
        let repetition: Int
        let elapsedSeconds: Double
        let cpuPercentOfOneCore: Double
        let mainThreadCPUPercentOfOneCore: Double
        let residentStart: UInt64
        let residentEnd: UInt64
        let residentSamples: [UInt64]
        let cpuPercentSamples: [Double]
        let mainThreadCPUPercentSamples: [Double]
        let cadenceLatenessMilliseconds: PerformanceDistribution
        let work: [String: Int]
        let foregroundThroughout: Bool
        let selectionPreserved: Bool
    }
    struct Report: Encodable {
        let schema = 1
        let revision: String
        let toolchain: String
        let hardware: String
        let architecture: String
        let os: String
        let processors: Int
        let buildMode: String
        let processID: Int32
        let fixture: [String: Int]
        let mainToFirstDrawMilliseconds: Double?
        let mainToPopulatedBodyMilliseconds: Double?
        let switchToBodyMilliseconds: PerformanceDistribution?
        let windowWidth: Double
        let windowHeight: Double
        let backingScale: Double
        let displayMaximumHz: Int
        let phases: [Phase]
        let error: String?
    }

    private(set) static weak var current: PerformanceSession?
    static func count(_ work: Work) { current?.counts[work, default: 0] += 1 }
    static func dashboardEvaluated(project: String?, populated: Bool) {
        count(.dashboardBody)
        guard let current else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if populated && current.firstPopulatedBody == nil { current.firstPopulatedBody = now }
        if let pending = current.pendingProject, pending == project {
            current.switchSamples.append((now - current.switchStarted) * 1_000)
            current.pendingProject = nil
        }
    }

    let dashboard = DashboardState()
    let progress = PerformanceProgress()
    let manual: Bool
    private var manualStarted = false
    private var counts: [Work: Int] = [:]
    private let enteredMain: Double
    private let output: URL
    private let fixture: [String: Int]
    private weak var window: NSWindow?
    private weak var store: FleetStore?
    private var subscriptions: [AnyCancellable] = []
    private var firstDraw: Double?
    private var firstPopulatedBody: Double?
    private var pendingProject: String?
    private var switchStarted = 0.0
    private var switchSamples: [Double] = []
    private var phases: [Phase] = []
    private var task: Task<Void, Never>?

    init(enteredMain: Double, output: URL, fixture: [String: Int], manual: Bool = false) {
        self.enteredMain = enteredMain
        self.output = output
        self.fixture = fixture
        self.manual = manual
        Self.current = self
    }

    func attach(window: NSWindow, store: FleetStore, companion: CompanionModel) {
        self.window = window
        self.store = store
        subscriptions = [
            dashboard.objectWillChange.sink { Self.count(.dashboardPublication) },
            dashboard.graphHover.objectWillChange.sink { Self.count(.hoverPublication) },
            companion.objectWillChange.sink { Self.count(.conversationPublication) },
        ]
        task = Task { await run() }
    }

    func willDraw() {
        Self.count(.nativeDraw)
        let now = ProcessInfo.processInfo.systemUptime
        if firstDraw == nil { firstDraw = now }
    }

    func stop() {
        task?.cancel()
        task = nil
        subscriptions = []
    }

    func startManual() { manualStarted = true }

    private func status(_ stage: String, nodes: Int) throws {
        progress.stage = stage
        let data = [
            "stage": stage, "nodes": String(nodes),
            "pid": String(ProcessInfo.processInfo.processIdentifier),
        ]
        try JSONEncoder().encode(data).write(
            to: output.deletingLastPathComponent()
                .appendingPathComponent("performance-status.json"), options: .atomic)
    }

    private func waitUntil(
        _ predicate: () -> Bool, seconds: Double,
        pollingMilliseconds: Int = 10
    ) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        while !predicate() {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                throw PerformanceFailure("Native fixture readiness or human start timed out")
            }
            try await Task.sleep(for: .milliseconds(pollingMilliseconds))
        }
    }

    private func select(_ count: Int) async throws {
        dashboard.graphHover.clear()
        pendingProject = "perf-\(count)"
        switchStarted = ProcessInfo.processInfo.systemUptime
        dashboard.projectID = pendingProject
        dashboard.selection = nil
        try await waitUntil({ self.pendingProject == nil }, seconds: 5)
        try await Task.sleep(for: .milliseconds(200))
    }

    private func phase(
        _ name: String, nodes: Int, seconds: Double, hover: Bool,
        repetition: Int = 0
    ) async throws {
        try status(name, nodes: nodes)
        let expectedProject = dashboard.projectID
        let ids =
            store?.snapshot?.missions.filter { $0.projectID == expectedProject }.map(\.id) ?? []
        guard ids.count == nodes else {
            throw PerformanceFailure("Synthetic node count does not match workload")
        }
        let before = try PerformanceResources.capture()
        let startingCounts = counts
        let start = ProcessInfo.processInfo.systemUptime
        var previous = start
        var nextMemorySample = start + 1
        var previousResource = before
        var previousResourceTime = start
        var memory: [UInt64] = []
        var cpu: [Double] = []
        var mainCPU: [Double] = []
        var lateness: [Double] = []
        var index = 0
        var foreground = true
        while ProcessInfo.processInfo.systemUptime - start < seconds {
            let interval = hover ? 1.0 / 60 : 0.05
            try await Task.sleep(for: .seconds(interval))
            let now = ProcessInfo.processInfo.systemUptime
            lateness.append(max(0, now - previous - interval) * 1_000)
            previous = now
            if hover, !ids.isEmpty {
                dashboard.graphHover.update(ids[index % ids.count], inside: true)
            }
            index += 1
            foreground = foreground && NSApp.isActive && window?.isVisible == true
            if now >= nextMemorySample {
                let resource = try PerformanceResources.capture()
                let interval = now - previousResourceTime
                memory.append(resource.residentBytes)
                cpu.append((resource.cpuSeconds - previousResource.cpuSeconds) / interval * 100)
                mainCPU.append(
                    (resource.callingThreadCPUSeconds - previousResource.callingThreadCPUSeconds)
                        / interval * 100)
                previousResource = resource
                previousResourceTime = now
                nextMemorySample = now + 1
            }
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        let after = try PerformanceResources.capture()
        let delta = Dictionary(
            uniqueKeysWithValues: Work.allCases.map {
                ($0.rawValue, counts[$0, default: 0] - startingCounts[$0, default: 0])
            })
        phases.append(
            Phase(
                name: name, nodes: nodes, repetition: repetition, elapsedSeconds: elapsed,
                cpuPercentOfOneCore: (after.cpuSeconds - before.cpuSeconds) / elapsed * 100,
                mainThreadCPUPercentOfOneCore: (after.callingThreadCPUSeconds
                    - before.callingThreadCPUSeconds) / elapsed * 100,
                residentStart: before.residentBytes, residentEnd: after.residentBytes,
                residentSamples: memory, cpuPercentSamples: cpu,
                mainThreadCPUPercentSamples: mainCPU,
                cadenceLatenessMilliseconds: try PerformanceDistribution(lateness),
                work: delta, foregroundThroughout: foreground,
                selectionPreserved: dashboard.projectID == expectedProject))
        dashboard.graphHover.clear()
        try await Task.sleep(for: .milliseconds(200))
    }

    private func run() async {
        var failure: String?
        do {
            try await waitUntil({ self.firstPopulatedBody != nil }, seconds: 15)
            if !manual {
                try await waitUntil(
                    { NSApp.isActive && self.window?.isVisible == true }, seconds: 300)
            }
            let expected = Set([0, 1, 4, 20, 100].map { "perf-\($0)" })
            guard Set(store?.snapshot?.projects.map(\.id) ?? []) == expected,
                store?.snapshot?.activeCount == 44
            else {
                throw PerformanceFailure(
                    "Performance probe requires its generated synthetic workspace")
            }
            try await Task.sleep(for: .seconds(2))
            if manual {
                try await select(20)
                try status("Ready for the one-minute physical cursor recording", nodes: 20)
                try await waitUntil(
                    { self.manualStarted }, seconds: 1_800, pollingMilliseconds: 100)
                try await phase("manual-pointer", nodes: 20, seconds: 60, hover: false)
                progress.cursorFinished = true
            } else {
                for _ in 0..<2 { for nodes in [0, 1, 4, 20, 100] { try await select(nodes) } }
            }
            for repetition in 1...3 {
                try await select(20)
                try await phase("idle", nodes: 20, seconds: 4, hover: false, repetition: repetition)
                for nodes in [4, 20, 100] {
                    try await select(nodes)
                    try await phase(
                        "hover-state", nodes: nodes, seconds: 8, hover: true, repetition: repetition
                    )
                }
            }
            try await phase("bounded-soak", nodes: 100, seconds: 30, hover: true)
        } catch {
            failure = error.localizedDescription
        }
        var switches: PerformanceDistribution?
        do {
            if !switchSamples.isEmpty { switches = try PerformanceDistribution(switchSamples) }
        } catch { failure = error.localizedDescription }
        let report = Report(
            revision: Bundle.main.object(forInfoDictionaryKey: "JarvisPerformanceRevision")
                as? String ?? "unknown",
            toolchain: Bundle.main.object(forInfoDictionaryKey: "JarvisPerformanceToolchain")
                as? String ?? "unknown",
            hardware: PerformanceResources.hardwareModel(),
            architecture: Bundle.main.object(forInfoDictionaryKey: "JarvisPerformanceArchitecture")
                as? String ?? "unknown",
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            processors: ProcessInfo.processInfo.processorCount, buildMode: "release-instrumented",
            processID: ProcessInfo.processInfo.processIdentifier,
            fixture: fixture,
            mainToFirstDrawMilliseconds: firstDraw.map { ($0 - enteredMain) * 1_000 },
            mainToPopulatedBodyMilliseconds: firstPopulatedBody.map { ($0 - enteredMain) * 1_000 },
            switchToBodyMilliseconds: switches,
            windowWidth: Double(window?.frame.width ?? 0),
            windowHeight: Double(window?.frame.height ?? 0),
            backingScale: Double(window?.backingScaleFactor ?? 0),
            displayMaximumHz: window?.screen?.maximumFramesPerSecond ?? 0,
            phases: phases, error: failure)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: output, options: .atomic)
            try status(
                failure == nil ? "Performance recording complete" : "Performance recording failed",
                nodes: phases.last?.nodes ?? 0)
            window?.title =
                failure == nil ? "Performance probe complete" : "Performance probe failed"
        } catch {
            FileHandle.standardError.write(
                Data("Could not write synthetic performance report.\n".utf8))
        }
    }
}

struct PerformanceStatusView: View {
    @ObservedObject var progress: PerformanceProgress
    let session: PerformanceSession
    var body: some View {
        VStack(spacing: 4) {
            Text(
                progress.stage == "manual-pointer"
                    ? "Recording cursor movement — 60 seconds" : progress.stage
            ).font(HUD.mono(10))
            if progress.cursorFinished, !progress.stage.hasPrefix("Performance recording") {
                Text("Your mouse part is complete — automatic checks are running").font(HUD.mono(9))
            }
            if session.manual, progress.stage.hasPrefix("Ready") {
                Button("Start 60-second cursor recording") { session.startManual() }
                    .accessibilityIdentifier("performance.startManual")
            }
        }.padding(8).foregroundStyle(HUD.gold).background(HUD.background)
    }
}

@MainActor final class PerformanceHostingView<Content: View>: NSHostingView<Content> {
    override func viewWillDraw() {
        PerformanceSession.current?.willDraw()
        super.viewWillDraw()
    }
}
