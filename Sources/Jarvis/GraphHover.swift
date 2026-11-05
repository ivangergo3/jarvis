import SwiftUI

/// Hover is local decoration: it must not republish dashboard or conversation state.
@MainActor final class GraphHoverState: ObservableObject {
    @Published private(set) var nodeID: String?
    func update(_ id: String, inside: Bool) {
        if inside {
            if nodeID != id { nodeID = id }
        } else if nodeID == id { nodeID = nil }
    }
    func clear() { if nodeID != nil { nodeID = nil } }
}

struct HoverTopology: View {
    @ObservedObject var hover: GraphHoverState
    let nodeIDs: [String]
    let selectedID: String?
    let active: [Bool]
    let motion: Bool
    let connections: [GraphConnection]
    var body: some View {
        TopologyLines(active: active, highlighted: nodeIDs.map { $0 == hover.nodeID || $0 == selectedID },
                      motion: motion, connections: connections)
    }
}

struct HoverDestination: ViewModifier {
    @ObservedObject var hover: GraphHoverState
    let nodeID: String
    let selected: Bool
    let active: Bool
    let motion: Bool
    let index: Int
    let left: Bool
    func body(content: Content) -> some View {
        content.modifier(GraphDestination(active: active, highlighted: selected || hover.nodeID == nodeID,
                                         motion: motion, index: index, left: left))
    }
}
