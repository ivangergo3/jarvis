import AppKit
import Foundation
import Testing

@testable import Jarvis

@Suite("UI verification isolation")
struct UIVerificationTests {
    @Test @MainActor func fixtureTerminationDoesNotWaitForAnotherMainActorTask() {
        let delegate = AppDelegate(
            source: VerificationFleetSource(.workspace),
            verification: UIVerification(scenario: .workspace, runID: UUID()))
        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    }
    @Test func malformedVerificationCannotFallBackToLiveMode() throws {
        #expect(try UIVerification.parse(["Jarvis"]) == nil)
        for arguments in [
            ["--ui-fixture"],
            ["--ui-fixture", "workspace"],
            ["--ui-run-id", UUID().uuidString],
            ["--ui-fixture", "unknown", "--ui-run-id", UUID().uuidString],
            ["--ui-fixture", "workspace", "--ui-run-id", "not-a-uuid"],
            ["--ui-fixture", "workspace", "--ui-run-id", UUID().uuidString, "--diagnose"],
        ] {
            #expect(throws: VerificationFailure.self) { try UIVerification.parse(arguments) }
        }
        let id = UUID()
        let parsed = try UIVerification.parse([
            "--ui-fixture", "workspace", "--ui-run-id", id.uuidString,
        ])
        let configuration = try #require(parsed)
        #expect(configuration.runID == id)
        #expect(configuration.scenario == .workspace)
    }

    @Test @MainActor func staleFixtureRetainsTheLastSnapshotAfterRefreshFailure() async {
        let source = VerificationFleetSource(.stale)
        let store = FleetStore(source: source)
        await store.refresh()
        #expect(store.error == nil)
        #expect(store.snapshot?.missions.count == 3)
        await store.refresh()
        #expect(store.error == "Synthetic source is unavailable.")
        #expect(store.snapshot?.missions.map(\.id) == ["alpha-one", "alpha-two", "beta-one"])
    }

    @Test @MainActor func fixtureTransportRecordsOnlyTheOriginalDestination() async throws {
        let evidence = VerificationEvidence()
        let connection = VerificationConnection { thread, text in
            await evidence.record(thread: thread, text: text)
        }
        let chat = CompanionModel(allowsExternalActions: false, makeConnection: { connection })
        let alpha = ConversationScope(
            projectID: "alpha", name: "Planning", directory: nil, threadID: "alpha-one")
        let beta = ConversationScope(
            projectID: "beta", name: "Planning", directory: nil, threadID: "beta-one")
        await chat.follow(alpha)
        chat.draft = "Fixture text"
        await chat.follow(beta)
        #expect(chat.draft.isEmpty)
        #expect(evidence.submission == "0 submissions")
        await chat.follow(alpha)
        #expect(chat.draft == "Fixture text")
        await chat.send(in: alpha)?.value
        #expect(evidence.submission == "1: alpha-one | Fixture text")
        #expect(chat.draft.isEmpty)
        await #expect(throws: ConnectionFailure.self) {
            try await connection.request("thread/start", params: .object([:]))
        }
        await chat.shutdown()
    }

    @Test @MainActor func disabledAudioDoesNotRequestPermissionOrStartRecording() async {
        let voice = LocalVoice(preferences: nil, allowsAudio: false)
        voice.readReplies = true
        voice.completionChime = true
        await voice.start()
        voice.announceCompletion("Synthetic reply")
        #expect(!voice.recording)
        #expect(voice.session.phase == .idle)
        #expect(voice.error == nil)
    }
}
