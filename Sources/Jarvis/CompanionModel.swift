import Combine
import Foundation

struct ConversationScope: Equatable, Sendable {
    let projectID: String?
    let name: String
    let directory: String?

    static let global = ConversationScope(projectID: nil, name: "Jarvis", directory: nil)
}

enum ConversationPhase: String, Sendable {
    case ready, connecting, sending, working, needsInput, complete, interrupted, failed,
        outcomeUnknown

    var busy: Bool { [.connecting, .sending, .working, .needsInput].contains(self) }
    var label: String {
        switch self {
        case .ready: return "READY"
        case .connecting: return "CONNECTING"
        case .sending: return "SENDING"
        case .working: return "WORKING"
        case .needsInput: return "NEEDS YOUR INPUT"
        case .complete: return "REPLY READY"
        case .interrupted: return "INTERRUPTED"
        case .failed: return "UNAVAILABLE"
        case .outcomeUnknown: return "SEND OUTCOME UNKNOWN"
        }
    }
}

struct CompanionMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }
    let id: String
    let role: Role
    var text: String
}

struct CompanionApproval: Identifiable {
    let id = UUID()
    let requestID: WireValue
    let method: String
    let params: WireValue
    var reviewContext: String = ""
    var questions: [WireValue] { params["questions"].values }
    var isQuestion: Bool { method == "item/tool/requestUserInput" }
    var details: String {
        let fields = [
            "command", "cwd", "reason", "networkApprovalContext", "additionalPermissions",
            "grantRoot",
        ]
        let summary = fields.compactMap { key -> String? in
            let value = params[key]
            if value == .null { return nil }
            if let text = value.text { return "\(key): \(text)" }
            guard let data = try? JSONEncoder().encode(value) else { return nil }
            return "\(key): \(String(decoding: data, as: UTF8.self))"
        }.joined(separator: "\n")
        return summary + (reviewContext.isEmpty ? "" : "\n\n" + reviewContext)
    }
    var decisions: [String] {
        let offered = params["availableDecisions"].values
        let choices =
            offered.isEmpty
            ? ["accept", "decline", "cancel"]
            : offered.compactMap(\.text).filter { ["accept", "decline", "cancel"].contains($0) }
        // Never offer a grant when the actual file change could not be presented completely.
        return method.contains("fileChange") && reviewContext.isEmpty
            ? choices.filter { $0 != "accept" } : choices
    }
}

/// One conversation owned by this app. Existing desktop chats remain observation-only (INT-02).
@MainActor final class CompanionModel: ObservableObject {
    @Published var draft = ""
    @Published private(set) var scope: ConversationScope?
    @Published private(set) var phase: ConversationPhase = .ready
    @Published private(set) var messages: [CompanionMessage] = []
    @Published private(set) var approvals: [CompanionApproval] = []
    @Published private(set) var notice: String?
    @Published private(set) var threadID: String?
    @Published private(set) var completedReply: String?
    @Published private(set) var answeringApproval = false
    private(set) var turnID: String?
    private let makeConnection: @Sendable () -> any CodexConnection
    private var connection: (any CodexConnection)?
    private var eventTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var generation = UUID()
    private var connectionID = UUID()
    private var initialized = false
    private var dispatched = false
    private var replyIDs: Set<String> = []
    private var fileChangeReviews: [String: String] = [:]

    init(
        makeConnection: @escaping @Sendable () -> any CodexConnection = {
            CodexProcessConnection(executable: CodexExecutable.locate())
        }
    ) { self.makeConnection = makeConnection }

    var canSend: Bool {
        !phase.busy && phase != .outcomeUnknown
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.count <= 16_000
    }

    func pinScope(_ proposed: ConversationScope) { if scope == nil { scope = proposed } }

    @discardableResult
    func send(in proposed: ConversationScope) -> Task<Void, Never>? {
        guard canSend else { return nil }
        pinScope(proposed)
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        messages.append(CompanionMessage(id: UUID().uuidString, role: .user, text: text))
        if messages.count > 100 { messages.removeFirst(messages.count - 100) }
        phase = .connecting
        notice = nil
        completedReply = nil
        dispatched = false
        replyIDs.removeAll()
        fileChangeReviews.removeAll()
        let token = generation
        sendTask = Task { [weak self] in await self?.performSend(text, generation: token) }
        return sendTask
    }

    private func performSend(_ text: String, generation token: UUID) async {
        do {
            if connection == nil {
                eventTask?.cancel()
                let epoch = UUID()
                connectionID = epoch
                let connection = makeConnection()
                self.connection = connection
                let stream = await connection.events()
                eventTask = Task { [weak self] in
                    for await event in stream {
                        guard !Task.isCancelled else { break }
                        await self?.consume(event, generation: token, connectionID: epoch)
                    }
                }
            }
            guard let connection else { throw ConnectionFailure.unavailable }
            if !initialized {
                _ = try await connection.request(
                    "initialize",
                    params: .object([
                        "clientInfo": .object([
                            "name": .string("jarvis_macos"),
                            "title": .string("Jarvis"), "version": .string("0.3.0"),
                        ])
                    ]))
                try await connection.notify("initialized")
                guard token == generation else { return }
                initialized = true
            }
            if threadID == nil {
                var params: [String: WireValue] = [:]
                if let directory = scope?.directory { params["cwd"] = .string(directory) }
                // Do not override the account's managed permission, sandbox or approval settings.
                let result = try await connection.request("thread/start", params: .object(params))
                guard token == generation else { return }
                guard let id = result["thread"]["id"].text, !id.isEmpty else {
                    throw ConnectionFailure.invalidRecord
                }
                threadID = id
            }
            guard token == generation, let threadID else { return }
            phase = .sending
            dispatched = true
            turnID = nil
            let result = try await connection.request(
                "turn/start",
                params: .object([
                    "threadId": .string(threadID),
                    "input": .array([.object(["type": .string("text"), "text": .string(text)])]),
                ]))
            guard token == generation else { return }
            guard let id = result["turn"]["id"].text else { throw ConnectionFailure.invalidRecord }
            turnID = id
            if phase == .sending { phase = .working }
        } catch {
            guard token == generation else { return }
            if [.complete, .interrupted].contains(phase) { return }
            // A protocol rejection is definite; a timeout/lost connection after dispatch is not.
            let definiteRejection: Bool
            if case ConnectionFailure.remote = error {
                definiteRejection = true
            } else {
                definiteRejection = false
            }
            phase = dispatched && !definiteRejection ? .outcomeUnknown : .failed
            notice = error.localizedDescription
            if !dispatched {
                await connection?.close()
                connection = nil
                initialized = false
            }
        }
    }

    func consume(
        _ event: CodexEvent, generation token: UUID? = nil, connectionID epoch: UUID? = nil
    ) async {
        guard token == nil || token == generation else { return }
        guard epoch == nil || epoch == connectionID else { return }
        if event.method == "jarvis/disconnected" {
            initialized = false
            if phase.busy { phase = dispatched ? .outcomeUnknown : .failed }
            if notice == nil {
                notice =
                    "Codex disconnected. Requests have not been replayed. Start a new chat if needed."
            }
            return
        }
        guard let threadID, event.params["threadId"].text == threadID else {
            if let id = event.requestID {
                try? await connection?.reject(id, message: "Not this Jarvis conversation")
            }
            return
        }
        let incomingTurn = event.params["turnId"].text ?? event.params["turn"]["id"].text
        if let turnID, let incomingTurn, turnID != incomingTurn {
            if let id = event.requestID {
                try? await connection?.reject(id, message: "Stale approval request")
            }
            return
        }
        if let id = event.requestID {
            guard
                [
                    "item/commandExecution/requestApproval", "item/fileChange/requestApproval",
                    "item/tool/requestUserInput",
                ].contains(event.method), approvals.count < 8
            else {
                try? await connection?.reject(
                    id,
                    message: "Approval type is not supported by Jarvis. No approval was granted.")
                notice = "Codex requested an unsupported approval. Jarvis did not grant it."
                return
            }
            approvals.append(
                CompanionApproval(
                    requestID: id, method: event.method, params: event.params,
                    reviewContext: fileChangeReviews[event.params["itemId"].text ?? ""] ?? ""))
            phase = .needsInput
            return
        }
        switch event.method {
        case "item/started", "item/completed":
            let item = event.params["item"]
            if item["type"].text == "fileChange", let id = item["id"].text,
                fileChangeReviews.count < 8, let data = try? JSONEncoder().encode(item),
                data.count <= 64_000
            {
                fileChangeReviews[id] = String(decoding: data, as: UTF8.self)
            }
        case "turn/started":
            turnID = incomingTurn
            phase = approvals.isEmpty ? .working : .needsInput
        case "item/agentMessage/delta":
            guard phase.busy, let id = event.params["itemId"].text,
                let delta = event.params["delta"].text
            else { return }
            replyIDs.insert(id)
            if let index = messages.firstIndex(where: { $0.id == id && $0.role == .assistant }) {
                messages[index].text = String((messages[index].text + delta).prefix(64_000))
            } else if messages.count < 100 {
                messages.append(
                    CompanionMessage(id: id, role: .assistant, text: String(delta.prefix(64_000))))
            }
        case "turn/completed":
            let status = event.params["turn"]["status"].text
            approvals.removeAll()
            if status == "completed" {
                phase = .complete
                completedReply =
                    messages.last(where: { $0.role == .assistant && replyIDs.contains($0.id) })?
                    .text
            } else if status == "interrupted" {
                phase = .interrupted
            } else {
                phase = .failed
                notice =
                    event.params["turn"]["error"]["message"].text
                    ?? "Codex could not complete this turn."
            }
            dispatched = false
        case "error": notice = event.params["message"].text ?? "Codex reported an error."
        default: break  // Tool output and instruction-like text are never interpreted as UI commands.
        }
    }

    func answer(
        _ approval: CompanionApproval, decision: String? = nil, answers: [String: String] = [:]
    ) async {
        guard !answeringApproval, approvals.first?.id == approval.id, let connection else { return }
        let result: WireValue
        if approval.isQuestion {
            let required = approval.questions.compactMap { $0["id"].text }
            guard
                required.allSatisfy({
                    !(answers[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                })
            else { return }
            result = .object([
                "answers": .object(
                    answers.mapValues { .object(["answers": .array([.string($0)])]) })
            ])
        } else {
            guard let decision, approval.decisions.contains(decision) else { return }
            result = .object(["decision": .string(decision)])
        }
        let token = generation
        answeringApproval = true
        defer { if token == generation { answeringApproval = false } }
        do {
            try await connection.respond(to: approval.requestID, result: result)
            guard token == generation, approvals.first?.id == approval.id else { return }
            approvals.removeFirst()
            phase = approvals.isEmpty ? .working : .needsInput
        } catch {
            guard token == generation else { return }
            phase = .outcomeUnknown
            notice = error.localizedDescription
        }
    }

    func interrupt() async {
        guard phase.busy else { return }
        guard let threadID, let turnID, let connection else {
            notice = "Still waiting for acknowledgement; a stop cannot yet be confirmed."
            return
        }
        let token = generation
        do {
            _ = try await connection.request(
                "turn/interrupt",
                params: .object([
                    "threadId": .string(threadID), "turnId": .string(turnID),
                ]))
        } catch {
            guard token == generation, phase.busy else { return }
            phase = .outcomeUnknown
            notice = error.localizedDescription
        }
    }

    func newConversation() async {
        guard !phase.busy else { return }
        phase = .connecting
        await shutdown()
        draft = ""
        scope = nil
        messages = []
        approvals = []
        notice = nil
        threadID = nil
        turnID = nil
        completedReply = nil
        phase = .ready
        dispatched = false
        answeringApproval = false
    }

    func shutdown() async {
        generation = UUID()
        connectionID = UUID()
        eventTask?.cancel()
        eventTask = nil
        sendTask?.cancel()
        sendTask = nil
        await connection?.close()
        connection = nil
        initialized = false
    }
}
