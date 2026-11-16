import Combine
import Foundation
import JarvisDomain
import Testing

@testable import Jarvis

private enum WorkspaceTestFailure: Error, LocalizedError {
    case unavailable
    var errorDescription: String? { "Synthetic workspace unavailable" }
}

private actor ControlledWorkspaceSource: WorkspaceSource {
    var result: Result<FleetSnapshot, any Error>
    private var held: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    private var pauseNext = false
    private var started = false
    private(set) var reads = 0

    init(_ result: Result<FleetSnapshot, any Error>) { self.result = result }
    func set(_ result: Result<FleetSnapshot, any Error>) { self.result = result }
    func pause() {
        pauseNext = true
        started = false
    }
    func waitUntilReading() async {
        if started { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func release() {
        held?.resume()
        held = nil
    }

    func read() async throws -> FleetSnapshot {
        reads += 1
        let response = result
        if pauseNext {
            pauseNext = false
            await withCheckedContinuation {
                held = $0
                started = true
                waiter?.resume()
                waiter = nil
            }
        }
        return try response.get()
    }
}

@Suite("Workspace presentation boundary", .timeLimit(.minutes(1)))
@MainActor struct FleetStoreTests {
    private func snapshot(_ seconds: TimeInterval = 0, notices: [String] = []) -> FleetSnapshot {
        FleetSnapshot(
            projects: [WorkspaceProject(id: "fixture", name: "Synthetic workspace", roots: [])],
            missions: [], readAt: Date(timeIntervalSince1970: 1_700_000_000 + seconds),
            notices: notices)
    }

    @Test func unchangedContentDoesNotRepublishJustBecauseTheClockAdvanced() async {
        let source = ControlledWorkspaceSource(.success(snapshot()))
        let store = FleetStore(source: source)
        var publications = 0
        let observation = store.$snapshot.sink { _ in publications += 1 }
        await store.refresh()
        #expect(store.snapshot?.projects.map(\.id) == ["fixture"])
        await source.set(.success(snapshot(10)))
        await store.refresh()
        #expect(publications == 2)  // initial nil and the first useful display
        #expect(store.snapshot?.readAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(store.error == nil)
        observation.cancel()
    }

    @Test func failureRetainsUsableSnapshotAndSuccessfulRefreshClearsTheError() async {
        let source = ControlledWorkspaceSource(.success(snapshot()))
        let store = FleetStore(source: source)
        await store.refresh()
        await source.set(.failure(WorkspaceTestFailure.unavailable))
        await store.refresh()
        #expect(store.snapshot?.projects.map(\.id) == ["fixture"])
        #expect(store.error == "Synthetic workspace unavailable")
        await source.set(.success(snapshot(20, notices: ["Synthetic update"])))
        await store.refresh()
        #expect(store.snapshot?.notices == ["Synthetic update"])
        #expect(store.error == nil)
        #expect(!store.refreshing)
    }

    @Test func overlappingRefreshesDoNotStartCompetingReads() async {
        let source = ControlledWorkspaceSource(.success(snapshot()))
        let store = FleetStore(source: source)
        await source.pause()
        let first = Task { await store.refresh() }
        await source.waitUntilReading()
        #expect(store.refreshing)
        await store.refresh()
        #expect(await source.reads == 1)
        await source.release()
        await first.value
        #expect(!store.refreshing)
        #expect(store.snapshot?.projects.first?.name == "Synthetic workspace")
    }

    @Test func cancelledLateSuccessCannotPublishAndTheNextRefreshCanRecover() async {
        let source = ControlledWorkspaceSource(.success(snapshot()))
        let store = FleetStore(source: source)
        await source.pause()
        let obsolete = Task { await store.refresh() }
        await source.waitUntilReading()
        obsolete.cancel()
        await store.refresh()
        #expect(await source.reads == 1)
        await source.release()
        await obsolete.value
        #expect(store.snapshot == nil)
        #expect(store.error == nil)
        #expect(!store.refreshing)
        await store.refresh()
        #expect(store.snapshot?.projects.map(\.id) == ["fixture"])
    }

    @Test func cancelledLateFailureDoesNotBecomeAVisibleWorkspaceError() async {
        let source = ControlledWorkspaceSource(.failure(WorkspaceTestFailure.unavailable))
        let store = FleetStore(source: source)
        await source.pause()
        let obsolete = Task { await store.refresh() }
        await source.waitUntilReading()
        obsolete.cancel()
        await source.release()
        await obsolete.value
        #expect(store.error == nil)
        #expect(!store.refreshing)
    }

    @Test func cancellationErrorAndAlreadyCancelledCallDoNotCreateFailureState() async {
        let source = ControlledWorkspaceSource(.failure(CancellationError()))
        let store = FleetStore(source: source)
        await store.refresh()
        #expect(store.error == nil)
        let cancelled = Task { await store.refresh() }
        cancelled.cancel()
        await cancelled.value
        #expect(await source.reads == 1)
        #expect(!store.refreshing)
    }
}
