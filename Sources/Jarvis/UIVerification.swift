import Foundation
import JarvisDomain
import SwiftUI

struct VerificationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum VerificationScenario: String, CaseIterable, Sendable {
    case workspace, empty, unavailable, stale
}

struct UIVerification: Sendable {
    let scenario: VerificationScenario
    let runID: UUID

    static func parse(_ arguments: [String]) throws -> Self? {
        let flags = ["--ui-fixture", "--ui-run-id"]
        guard flags.contains(where: arguments.contains) else { return nil }
        func value(_ flag: String) throws -> String {
            guard arguments.filter({ $0 == flag }).count == 1,
                let index = arguments.firstIndex(of: flag), index + 1 < arguments.count
            else {
                throw VerificationFailure(
                    message: "UI verification requires a scenario and run UUID.")
            }
            return arguments[index + 1]
        }
        guard !arguments.contains("--diagnose"), !arguments.contains("--workspace-fixture"),
            let scenario = VerificationScenario(rawValue: try value("--ui-fixture")),
            let runID = UUID(uuidString: try value("--ui-run-id"))
        else { throw VerificationFailure(message: "Invalid UI verification launch configuration.") }
        return Self(scenario: scenario, runID: runID)
    }
}

actor VerificationFleetSource: WorkspaceSource {
    private let scenario: VerificationScenario
    private var reads = 0
    init(_ scenario: VerificationScenario) { self.scenario = scenario }

    func read() throws -> FleetSnapshot {
        reads += 1
        if scenario == .unavailable || (scenario == .stale && reads > 1) {
            throw VerificationFailure(message: "Synthetic source is unavailable.")
        }
        let date = Date(timeIntervalSince1970: 1_767_225_600)
        let projects = [
            WorkspaceProject(id: "alpha", name: "Alpha Workshop", roots: []),
            WorkspaceProject(id: "beta", name: "Beta Workshop", roots: []),
            WorkspaceProject(id: "empty", name: "Empty Workshop", roots: []),
        ]
        let missions = ["alpha-one", "alpha-two", "beta-one"].map { id in
            Mission(
                id: id, projectID: id.hasPrefix("alpha") ? "alpha" : "beta",
                name: id == "alpha-two" ? "Release checks" : "Planning",
                role: "FIXTURE", symbol: "bubble.left", task: "Synthetic task for \(id)",
                status: .working, updated: date, sourcePath: "", sourceLabel: "Synthetic")
        }
        return FleetSnapshot(
            projects: scenario == .empty ? [] : projects,
            missions: scenario == .empty ? [] : missions,
            readAt: date, notices: [])
    }
}

@MainActor final class VerificationEvidence: ObservableObject {
    @Published private(set) var submission = "0 submissions"
    private var count = 0
    func record(thread: String, text: String) {
        count += 1
        submission = "\(count): \(thread) | \(text)"
    }
}

/// Closed in-memory transport. Unsupported methods fail; no process or network fallback exists.
actor VerificationConnection: CodexConnection {
    private var queues: [String: [WireValue]] = [:]
    private let record: @Sendable (String, String) async -> Void
    init(record: @escaping @Sendable (String, String) async -> Void) { self.record = record }

    func request(_ method: String, params: WireValue) async throws -> WireValue {
        if method == "initialize" { return .object([:]) }
        guard let thread = params["threadId"].text,
            ["alpha-one", "alpha-two", "beta-one"].contains(thread)
        else { throw ConnectionFailure.invalidRecord }
        switch method {
        case "thread/turns/list": return .object(["data": .array([])])
        case "thread/queue/list": return .object(["data": .array(queues[thread] ?? [])])
        case "thread/queue/add":
            guard let client = params["clientUserMessageId"].text,
                !params["input"].values.isEmpty,
                params["input"].values.allSatisfy({ $0["type"].text == "text" })
            else { throw ConnectionFailure.invalidRecord }
            let submission: WireValue = .object([
                "id": .string("fixture-\(client)"), "clientUserMessageId": .string(client),
                "input": params["input"],
            ])
            queues[thread, default: []].append(submission)
            await record(thread, params["input"].values.compactMap { $0["text"].text }.joined())
            return .object(["queuedSubmission": submission])
        default: throw ConnectionFailure.remote("Unsupported synthetic transport method.")
        }
    }
    func notify(_ method: String) throws {
        guard method == "initialized" else { throw ConnectionFailure.invalidRecord }
    }
    func respond(to id: WireValue, result: WireValue) throws {
        throw ConnectionFailure.invalidRecord
    }
    func reject(_ id: WireValue, message: String) throws { throw ConnectionFailure.invalidRecord }
    func events() -> AsyncStream<CodexEvent> { AsyncStream { $0.finish() } }
    func close() {}
}

struct VerificationBanner: View {
    let configuration: UIVerification
    @ObservedObject var evidence: VerificationEvidence
    var body: some View {
        HStack {
            Text("Synthetic verification · \(configuration.scenario.rawValue)")
            Text(configuration.runID.uuidString)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(configuration.runID.uuidString)
                .accessibilityIdentifier("verification.run")
            Text(evidence.submission)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(evidence.submission)
                .accessibilityIdentifier("verification.submissions")
        }.font(.system(size: 10)).padding(8).foregroundStyle(.white).background(.black)
    }
}
