import Combine
import Foundation
import Testing

@testable import Jarvis

@Suite("Deterministic performance contracts")
@MainActor struct PerformanceRegressionTests {
    @Test(arguments: [1, 4, 20, 100, 1_000])
    func hoverLoadOnlyNotifiesChangedCards(cardCount: Int) {
        let dashboard = DashboardState(preferences: nil)
        let hover = dashboard.graphHover
        let cards = (0..<cardCount).map { hover.destination(for: "synthetic-\($0)") }
        var notifications = Array(repeating: 0, count: cardCount)
        var rootUpdates = 0
        let root = dashboard.objectWillChange.sink { rootUpdates += 1 }
        let observers = cards.enumerated().map { index, card in
            card.objectWillChange.sink { notifications[index] += 1 }
        }
        let iterations = 10_000
        for index in 0..<iterations {
            let next = index % cardCount
            hover.update("synthetic-\(next)", inside: true)
            hover.update("synthetic-\(next)", inside: true)
            // A late exit for another card must not clear the current highlight.
            hover.update("not-mounted", inside: false)
        }
        hover.clear()
        hover.clear()
        #expect(notifications.reduce(0, +) == (cardCount == 1 ? 2 : iterations * 2))
        #expect(cards.allSatisfy { !$0.highlighted })
        #expect(rootUpdates == 0)
        withExtendedLifetime(observers) {}
        root.cancel()
    }

    @Test func hoverStateReusesMountedCardsAndReleasesUnmountedCards() {
        let hover = GraphHoverState()
        hover.update("active", inside: true)
        var card: GraphHoverDestination? = hover.destination(for: "active")
        final class WeakCard {
            weak var value: GraphHoverDestination?
            init(_ value: GraphHoverDestination?) { self.value = value }
        }
        let released = WeakCard(card)
        #expect(card?.highlighted == true)
        #expect(card === hover.destination(for: "active"))
        card = nil
        #expect(released.value == nil)
        let replacement = hover.destination(for: "active")
        #expect(replacement.highlighted)
        hover.update("next", inside: true)
        hover.update("active", inside: false)
        #expect(!replacement.highlighted)
        #expect(hover.nodeID == "next")
    }

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
