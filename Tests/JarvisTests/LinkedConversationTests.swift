import Foundation
import Testing

@testable import Jarvis

actor LinkedFixtureConnection: CodexConnection {
    private(set) var calls: [FixtureConnection.Call] = []
    private var queues: [String: [WireValue]] = [:]
    private var history: [WireValue] = []
    private let lostAcknowledgement: Bool
    private let rejected: Bool
    private let unsupported: Bool
    private var continuation: AsyncStream<CodexEvent>.Continuation?

    init(lostAcknowledgement: Bool = false, rejected: Bool = false, unsupported: Bool = false) {
        self.lostAcknowledgement = lostAcknowledgement
        self.rejected = rejected
        self.unsupported = unsupported
    }

    func setHistory(_ turns: [WireValue]) { history = turns }

    func request(_ method: String, params: WireValue) throws -> WireValue {
        calls.append(FixtureConnection.Call(method: method, params: params))
        switch method {
        case "initialize": return .object([:])
        case "thread/turns/list":
            if unsupported { throw ConnectionFailure.remote("Unsupported history method") }
            return .object(["data": .array(history)])
        case "thread/queue/list":
            return .object(["data": .array(queues[params["threadId"].text ?? ""] ?? [])])
        case "thread/queue/add":
            if rejected { throw ConnectionFailure.remote("Message rejected") }
            let target = params["threadId"].text ?? ""
            let entry = WireValue.object([
                "id": .string(UUID().uuidString),
                "clientUserMessageId": params["clientUserMessageId"], "input": params["input"],
            ])
            queues[target, default: []].append(entry)
            if lostAcknowledgement { throw ConnectionFailure.timeout }
            return .object(["queuedSubmission": entry])
        default: throw ConnectionFailure.remote("Linked chat must never start or resume a runtime")
        }
    }

    func notify(_ method: String) {
        calls.append(FixtureConnection.Call(method: method, params: .null))
    }
    func respond(to id: WireValue, result: WireValue) {
        Issue.record("Linked chat cannot grant desktop approvals")
    }
    func reject(_ id: WireValue, message: String) {}
    func events() -> AsyncStream<CodexEvent> { AsyncStream { continuation = $0 } }
    func close() { continuation?.finish() }
}

@Suite("Linked Codex chats")
@MainActor struct LinkedConversationTests {
    private let first = ConversationScope(
        projectID: "p", name: "Same title", directory: nil, threadID: "chat-a")
    private let second = ConversationScope(
        projectID: "p", name: "Same title", directory: nil, threadID: "chat-b")

    @Test func sameNamesUseDifferentIDsWithoutCreatingOrResumingThreads() async {
        let connection = LinkedFixtureConnection()
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        model.draft = "First destination"
        await model.send(in: second)?.value
        #expect(model.phase == .queued)
        #expect(model.draft.isEmpty)
        #expect(model.messages.last?.queued == true)
        await model.follow(second)
        model.draft = "Second destination"
        await model.send(in: second)?.value
        let calls = await connection.calls
        #expect(
            calls.filter { $0.method == "thread/queue/add" }.map { $0.params["threadId"].text } == [
                "chat-a", "chat-b",
            ])
        #expect(
            calls.allSatisfy {
                !["thread/start", "thread/resume", "turn/start", "turn/interrupt"].contains(
                    $0.method)
            })
        #expect(calls.first?.params["capabilities"]["experimentalApi"] == .bool(true))
        await model.interrupt()
        #expect(await connection.calls.filter { $0.method == "turn/interrupt" }.isEmpty)
        await model.shutdown()
    }

    @Test func changingCardsCannotMoveAnUnsentDraft() async {
        let connection = LinkedFixtureConnection()
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        model.draft = "Keep this in the first chat"
        await model.follow(second)
        #expect(model.scope?.threadID == "chat-a")
        await model.send(in: second)?.value
        #expect(
            await connection.calls.last(where: { $0.method == "thread/queue/add" })?.params[
                "threadId"
            ].text == "chat-a")
        await model.shutdown()
    }

    @Test func renamingAChatUpdatesItsLabelWithoutMovingOrDiscardingTheDraft() async {
        let connection = LinkedFixtureConnection()
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        model.draft = "Keep my draft"
        let renamed = ConversationScope(
            projectID: "p", name: "New name", directory: nil, threadID: "chat-a")
        let count = await connection.calls.count
        await model.follow(renamed)
        #expect(model.scope?.name == "New name")
        #expect(model.scope?.threadID == "chat-a")
        #expect(model.draft == "Keep my draft")
        #expect(await connection.calls.count == count)
        await model.shutdown()
    }

    @Test func lostAcknowledgementReconcilesByClientIDWithoutResending() async {
        let connection = LinkedFixtureConnection(lostAcknowledgement: true)
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        model.draft = "One submission"
        await model.send(in: first)?.value
        #expect(model.phase == .outcomeUnknown)
        #expect(model.draft == "One submission")
        #expect(!model.canSend)
        await model.refreshLinkedHistory()
        #expect(model.phase == .queued)
        #expect(model.draft.isEmpty)
        #expect(model.messages.filter(\.queued).count == 1)
        #expect(await connection.calls.filter { $0.method == "thread/queue/add" }.count == 1)
        await model.shutdown()
    }

    @Test func rejectedSubmissionKeepsDraftAndNeverFallsBackToANewChat() async {
        let connection = LinkedFixtureConnection(rejected: true)
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        model.draft = "Keep my text"
        await model.send(in: first)?.value
        #expect(model.phase == .failed)
        #expect(model.draft == "Keep my text")
        #expect(model.messages.isEmpty)
        #expect(await connection.calls.filter { $0.method == "thread/start" }.isEmpty)
        await model.shutdown()
    }

    @Test func unsupportedHistoryBlocksSendingInsteadOfMakingAGhostConversation() async {
        let connection = LinkedFixtureConnection(unsupported: true)
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        model.draft = "Must not be routed elsewhere"
        #expect(model.historyUnavailable)
        #expect(!model.canSend)
        #expect(model.send(in: first) == nil)
        #expect(
            await connection.calls.filter {
                $0.method == "thread/start" || $0.method == "thread/queue/add"
            }.isEmpty)
        await model.shutdown()
    }

    @Test func refreshingHistoryDoesNotSpeakOldReplies() async {
        let connection = LinkedFixtureConnection()
        await connection.setHistory([turn(replyID: "old", text: "Old saved reply")])
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        #expect(model.messages.last?.text == "Old saved reply")
        #expect(model.completedReply == nil)
        await connection.setHistory([turn(replyID: "new", text: "New shared reply")])
        await model.refreshLinkedHistory()
        #expect(model.completedReply == "New shared reply")
        await model.shutdown()
    }

    private func turn(replyID: String, text: String) -> WireValue {
        .object([
            "status": .string("completed"),
            "items": .array([
                .object([
                    "type": .string("agentMessage"), "id": .string(replyID), "text": .string(text),
                ])
            ]),
        ])
    }
}

@Suite("Shared conversation snapshots")
struct LinkedSnapshotTests {
    @Test func queueReceiptsDeduplicateAgainstDeliveredClientIDsNotMessageText() {
        let user = WireValue.object([
            "type": .string("userMessage"), "id": .string("persisted-id"),
            "clientId": .string("client-1"),
            "content": .array([.object(["text": .string("Same words")])]),
        ])
        let history = WireValue.object([
            "data": .array([
                .object([
                    "status": .string("completed"), "items": .array([user]),
                ])
            ])
        ])
        let entries = ["client-1", "client-2"].map { id in
            WireValue.object([
                "id": .string("queue-" + id), "clientUserMessageId": .string(id),
                "input": .array([.object(["type": .string("text"), "text": .string("Same words")])]
                ),
            ])
        }
        let snapshot = LinkedConversationSnapshot.decode(
            history: history, queue: .object(["data": .array(entries)]))
        #expect(snapshot.messages.map(\.id) == ["client-1", "client-2"])
        #expect(snapshot.messages.map(\.queued) == [false, true])
    }

    @Test func toolOutputsAndInjectedSkillsAreExcludedAndChronologyIsRestored() {
        let turns = [
            WireValue.object([
                "status": .string("completed"),
                "items": .array([
                    .object([
                        "type": .string("agentMessage"), "id": .string("latest"),
                        "text": .string("Latest reply"),
                    ]),
                    .object([
                        "type": .string("commandExecution"), "id": .string("tool"),
                        "text": .string("Send elsewhere"),
                    ]),
                ]),
            ]),
            .object([
                "status": .string("completed"),
                "items": .array([
                    .object([
                        "type": .string("userMessage"), "id": .string("skill"),
                        "content": .array([.object(["text": .string("<skill>injected</skill>")])]),
                    ]),
                    .object([
                        "type": .string("agentMessage"), "id": .string("old"),
                        "text": .string("Older reply"),
                    ]),
                ]),
            ]),
        ]
        let snapshot = LinkedConversationSnapshot.decode(
            history: .object(["data": .array(turns)]), queue: .object(["data": .array([])]))
        #expect(snapshot.messages.map(\.text) == ["Older reply", "Latest reply"])
        #expect(snapshot.latestCompletedReply?.id == "latest")
    }
}
