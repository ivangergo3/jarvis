import Foundation
import Testing

@testable import Jarvis

@Suite("Controlled lifecycle time")
struct LifecycleBoundaryTests {
    @Test func startMarkerExpiresOnlyAfterThirtyMinutes() async throws {
        let fixture = try SessionFixture()
        let file = try fixture.addThread()
        let modified = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes(
            [.modificationDate: modified], ofItemAtPath: file.path)
        let boundary = modified.addingTimeInterval(1_800)
        let atBoundary = try await CodexReader(home: fixture.home, now: { boundary }).read()
        #expect(atBoundary.readAt == boundary)
        #expect(atBoundary.missions.first?.status == .working)
        let afterBoundary = try await CodexReader(
            home: fixture.home, now: { boundary.addingTimeInterval(1) }
        ).read()
        #expect(afterBoundary.missions.first?.status == .unknown)
    }
}

@Suite("Untrusted protocol boundaries")
struct ProtocolBoundaryTests {
    @Test func validJSONThatIsNotAnObjectIsRejected() {
        for record in ["[]", "null", "42", "true", "\"text\""] {
            var parser = ProtocolLines()
            #expect(throws: ConnectionFailure.invalidRecord) {
                try parser.feed(Data((record + "\n").utf8))
            }
        }
    }

    @Test func exactFrameLimitIsAcceptedButOneMoreByteIsRejected() throws {
        // Count the literal framing bytes independently of the parser's buffer logic.
        let prefix = "{\"text\":\""
        let suffix = "\"}"
        let payload = String(
            repeating: "a", count: 1_048_576 - prefix.utf8.count - suffix.utf8.count)
        var parser = ProtocolLines()
        #expect(
            try parser.feed(Data((prefix + payload + suffix + "\n").utf8)) == [
                .object(["text": .string(payload)])
            ])
        var oversized = ProtocolLines()
        #expect(throws: ConnectionFailure.invalidRecord) {
            try oversized.feed(Data((prefix + payload + "a" + suffix + "\n").utf8))
        }
    }

    @Test func deterministicChunkingPreservesKnownRecords() throws {
        let input = Data("{\"text\":\"🦾\\nhello\"}\n{\"id\":7}\n{\"done\":true}\n".utf8)
        let expected: [WireValue] = [
            .object(["text": .string("🦾\nhello")]),
            .object(["id": .number(7)]), .object(["done": .bool(true)]),
        ]
        for seed in 1...64 {
            var state = UInt64(seed)
            var parser = ProtocolLines()
            var records: [WireValue] = []
            var offset = 0
            while offset < input.count {
                state = state &* 6_364_136_223_846_793_005 &+ 1
                let end = min(input.count, offset + Int(state % 13) + 1)
                records += try parser.feed(input.subdata(in: offset..<end))
                offset = end
            }
            #expect(records == expected, "Chunk seed: \(seed)")
        }
    }
}

/// Explicit latches force the dangerous interleaving; there are no timing sleeps.
/// A closed connection may still return an already received response, as real I/O can.
private actor DelayedHistoryConnection: CodexConnection {
    private var pause = false
    private var started = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var held: CheckedContinuation<Void, Never>?
    private var queue: [WireValue] = []
    private var receiptID: WireValue = .null
    private(set) var submissions = 0
    private let loseAcknowledgement: Bool
    private var stream: AsyncStream<CodexEvent>.Continuation?

    init(loseAcknowledgement: Bool = false) { self.loseAcknowledgement = loseAcknowledgement }
    func pauseNextHistory() {
        pause = true
        started = false
    }
    func waitForHistory() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func releaseHistory() {
        held?.resume()
        held = nil
    }
    func publishMatchingReceipt() { queue = [receipt(id: receiptID)] }
    private func receipt(id: WireValue) -> WireValue {
        .object([
            "id": .string("queue-receipt"), "clientUserMessageId": id,
            "input": .array([.object(["type": .string("text"), "text": .string("Same words")])]),
        ])
    }
    func request(_ method: String, params: WireValue) async throws -> WireValue {
        switch method {
        case "initialize": return .object([:])
        case "thread/turns/list":
            let target = params["threadId"].text ?? "missing"
            let response = WireValue.object([
                "data": .array([
                    .object([
                        "status": .string("completed"),
                        "items": .array([
                            .object([
                                "type": .string("agentMessage"), "id": .string("reply-" + target),
                                "text": .string("Reply for " + target),
                            ])
                        ]),
                    ])
                ])
            ])
            if pause {
                pause = false
                await withCheckedContinuation { continuation in
                    held = continuation
                    started = true
                    startWaiter?.resume()
                    startWaiter = nil
                }
            }
            return response
        case "thread/queue/list": return .object(["data": .array(queue)])
        case "thread/queue/add":
            submissions += 1
            receiptID = params["clientUserMessageId"]
            if loseAcknowledgement {
                queue = [receipt(id: .string("another-client-with-identical-text"))]
                throw ConnectionFailure.timeout
            }
            return .object(["queuedSubmission": receipt(id: receiptID)])
        default: throw ConnectionFailure.invalidRecord
        }
    }
    func notify(_ method: String) {}
    func respond(to id: WireValue, result: WireValue) {
        Issue.record("Unexpected approval side effect")
    }
    func reject(_ id: WireValue, message: String) {}
    func events() -> AsyncStream<CodexEvent> { AsyncStream { stream = $0 } }
    func close() { stream?.finish() }
}

@Suite("Asynchronous conversation regressions", .timeLimit(.minutes(1)))
@MainActor struct ConversationRegressionTests {
    private let first = ConversationScope(
        projectID: "p", name: "Same title", directory: nil, threadID: "a")
    private let second = ConversationScope(
        projectID: "p", name: "Same title", directory: nil, threadID: "b")

    @Test func lateHistoryAfterDestinationChangeCannotReplaceTheNewChat() async {
        let connection = DelayedHistoryConnection()
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        await connection.pauseNextHistory()
        let oldRefresh = Task { await model.refreshLinkedHistory() }
        await connection.waitForHistory()
        await model.follow(second)
        #expect(model.scope?.threadID == "b")
        #expect(model.messages.map(\.text) == ["Reply for b"])
        await connection.releaseHistory()
        await oldRefresh.value
        #expect(model.messages.map(\.text) == ["Reply for b"])
        #expect(model.completionID == nil)
        await model.shutdown()
    }

    @Test func historyStartedBeforeSendCannotEraseTheQueuedMessage() async {
        let connection = DelayedHistoryConnection()
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        await connection.pauseNextHistory()
        let oldRefresh = Task { await model.refreshLinkedHistory() }
        await connection.waitForHistory()
        model.draft = "Same words"
        await model.send(in: first)?.value
        #expect(model.phase == .queued)
        await connection.releaseHistory()
        await oldRefresh.value
        #expect(model.messages.last?.text == "Same words")
        #expect(model.messages.last?.queued == true)
        #expect(await connection.submissions == 1)
        await model.shutdown()
    }

    @Test func identicalTextWithWrongReceiptCannotResolveAnUncertainSend() async {
        let connection = DelayedHistoryConnection(loseAcknowledgement: true)
        let model = CompanionModel(makeConnection: { connection })
        await model.follow(first)
        model.draft = "Same words"
        await model.send(in: first)?.value
        await model.refreshLinkedHistory()
        #expect(model.phase == .outcomeUnknown)
        #expect(model.draft == "Same words")
        #expect(!model.canSend)
        #expect(model.send(in: first) == nil)
        await connection.publishMatchingReceipt()
        await model.refreshLinkedHistory()
        #expect(model.phase == .queued)
        #expect(model.draft.isEmpty)
        #expect(await connection.submissions == 1)
        await model.shutdown()
    }
}
