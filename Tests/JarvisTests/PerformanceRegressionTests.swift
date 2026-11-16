import Combine
import Foundation
import Testing

@testable import Jarvis

@Suite("Deterministic performance contracts")
@MainActor struct PerformanceRegressionTests {
    @Test func measurementSummaryPreservesSlowSamplesAndRejectsMissingMeasurements() throws {
        let summary = try PerformanceDistribution([4, 1, 100, 2, 3])
        #expect(summary.samples == [4, 1, 100, 2, 3])
        #expect(summary.minimum == 1)
        #expect(summary.median == 3)
        #expect(summary.p95 == 100)
        #expect(summary.maximum == 100)
        #expect(try PerformanceDistribution([1, 2, 3, 4]).median == 2.5)
        for invalid in [[], [Double.nan], [Double.infinity], [-1]] {
            #expect(throws: PerformanceFailure.self) { try PerformanceDistribution(invalid) }
        }
    }

    @Test func sustainedHoverDoesNotInvalidateDashboardOrConversation() {
        let dashboard = DashboardState()
        let connection = FixtureConnection()
        let conversation = CompanionModel(makeConnection: { connection })
        var rootUpdates = 0
        var conversationUpdates = 0
        let root = dashboard.objectWillChange.sink { rootUpdates += 1 }
        let chat = conversation.objectWillChange.sink { conversationUpdates += 1 }
        for index in 0..<10_000 {
            let previous = "synthetic-\(max(0, index - 1) % 100)"
            let next = "synthetic-\(index % 100)"
            dashboard.graphHover.update(next, inside: true)
            dashboard.graphHover.update(next, inside: true)  // duplicate enter
            dashboard.graphHover.update(previous, inside: false)  // stale exit
        }
        #expect(dashboard.graphHover.nodeID == "synthetic-99")
        #expect(rootUpdates == 0)
        #expect(conversationUpdates == 0)
        #expect(conversation.messages.isEmpty)
        root.cancel()
        chat.cancel()
    }
}
