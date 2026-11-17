import SwiftUI

struct HoverTopology: View {
    @ObservedObject var hover: GraphHoverState
    let nodeIDs: [String]
    let selectedID: String?
    let active: [Bool]
    let motion: Bool
    let connections: [GraphConnection]
    var body: some View {
        let _ = RenderWorkCounters.count(.hoverTopologyBody)
        TopologyLines(
            active: active, highlighted: nodeIDs.map { $0 == hover.nodeID || $0 == selectedID },
            motion: motion, connections: connections)
    }
}

struct HoverDestination: ViewModifier {
    @ObservedObject var destination: GraphHoverDestination
    let selected: Bool
    let active: Bool
    let motion: Bool
    let index: Int
    let left: Bool
    func body(content: Content) -> some View {
        let _ = RenderWorkCounters.count(.hoverDestinationBody)
        content.modifier(
            GraphDestination(
                active: active, highlighted: selected || destination.highlighted,
                motion: motion, index: index, left: left))
    }
}
