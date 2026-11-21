import Combine
import Foundation
import JarvisDomain
import Testing

@testable import Jarvis

private actor ParityWorkspace: WorkspaceSource {
    private let count: Int
    private var revision = 0
    private(set) var reads = 0
    init(count: Int) { self.count = count }
    func changeTask() { revision += 1 }
    func read() async throws -> FleetSnapshot {
        reads += 1
        return FleetSnapshot(
            projects: [.init(id: "fixture", name: "Synthetic project", roots: [])],
            missions: (0..<count).map { index in
                Mission(
                    id: "chat-\(index)", projectID: "fixture", name: "Chat \(index)",
                    role: "Fixture", symbol: "bubble.left",
                    task: index == 0 ? "Task \(revision)" : "Task",
                    status: .working, updated: Date(timeIntervalSince1970: 0),
                    sourcePath: "", sourceLabel: "Synthetic")
            }, readAt: Date(timeIntervalSince1970: Double(reads)), notices: [])
    }
}

@Suite("Rewrite parity baseline", .timeLimit(.minutes(1)))
@MainActor struct RewriteBaselineTests {
    @Test func richMessageKeepsTableCodeImageAndFollowingTextDistinct() {
        let blocks = ChatMarkdown.blocks(
            """
            ## Result
            > Review this
            - **Keep** the layout
            1. Verify it

            | Task | State |
            | --- | --- |
            | Build | Done |

            ```text
            | literal | code |
            ![not an attachment](/tmp/literal.png)
            ```

            ![Synthetic image](/tmp/synthetic.png)

            Final paragraph.
            """
        )
        #expect(blocks.count == 8)
        #expect(
            blocks.prefix(4) == [
                .heading(2, "Result"), .quote("Review this"), .list("•", "**Keep** the layout"),
                .list("1.", "Verify it"),
            ])
        guard blocks.count == 8, case .table(let table) = blocks[4] else {
            Issue.record("Mixed message lost its table or block boundaries")
            return
        }
        #expect(table.headers == ["Task", "State"])
        #expect(table.rows == [["Build", "Done"]])
        #expect(blocks[5] == .code("| literal | code |\n![not an attachment](/tmp/literal.png)"))
        #expect(blocks[6] == .image(.init(name: "Synthetic image", location: "/tmp/synthetic.png")))
        #expect(blocks[7] == .paragraph("Final paragraph."))
    }

    @Test(arguments: [1, 4, 20, 100])
    func routesReachTheirOwnCardEdgesAtNarrowAndWideSizes(count: Int) {
        for viewport in [CGSize(width: 500, height: 600), CGSize(width: 1600, height: 900)] {
            let layout = TeamGraphLayout(count: count, viewport: viewport)
            #expect(layout.nodes.count == count)
            #expect(layout.connections.count == count)
            for (node, route) in zip(layout.nodes, layout.connections) {
                let endpoint = route.point(at: 1)
                #expect(endpoint.y == node.y)
                let inwardOffset =
                    node.x < layout.center.x ? layout.cardWidth / 2 : -layout.cardWidth / 2
                #expect(abs(endpoint.x - (node.x + inwardOffset)) < 0.001)
                #expect(route.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
                for pair in zip(route.points, route.points.dropFirst()) {
                    #expect(pair.0.x == pair.1.x || pair.0.y == pair.1.y)
                }
            }
        }
    }

    @Test(arguments: [20, 100])
    func refreshAndHoverLoadPreserveLocalUpdatesAndDeliverChangedTask(count: Int) async {
        let source = ParityWorkspace(count: count)
        let store = FleetStore(source: source)
        let dashboard = DashboardState(preferences: nil)
        let cards = (0..<count).map { dashboard.graphHover.destination(for: "chat-\($0)") }
        var snapshots = 0
        var rootUpdates = 0
        let snapshotObserver = store.$snapshot.sink { _ in snapshots += 1 }
        let rootObserver = dashboard.objectWillChange.sink { rootUpdates += 1 }
        defer {
            snapshotObserver.cancel()
            rootObserver.cancel()
        }
        await store.refresh()
        #expect(snapshots == 2)
        #expect(store.snapshot?.missions.first?.task == "Task 0")
        for refresh in 0..<250 {
            if refresh == 125 { await source.changeTask() }
            for move in 0..<40 {
                let current = (refresh * 40 + move) % count
                dashboard.graphHover.update("chat-\(current)", inside: true)
                #expect(cards[current].highlighted)
                #expect(!cards[(current + count - 1) % count].highlighted)
            }
            await store.refresh()
            #expect(snapshots == (refresh < 125 ? 2 : 3))
            #expect(store.snapshot?.missions.first?.task == (refresh < 125 ? "Task 0" : "Task 1"))
        }
        dashboard.graphHover.clear()
        #expect(await source.reads == 251)
        #expect(snapshots == 3)  // Initial nil, first content, one genuinely changed task.
        #expect(rootUpdates == 0)
        #expect(store.snapshot?.missions.count == count)
        #expect(store.snapshot?.missions.first?.task == "Task 1")
        #expect(cards.allSatisfy { !$0.highlighted })
        #expect(!store.refreshing && store.error == nil)
    }
}
