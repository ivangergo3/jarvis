import SwiftUI

struct HoverTopology: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let hover: GraphHoverState
    let nodeIDs: [String]
    let selectedID: String?
    let active: [Bool]
    let motion: Bool
    let connections: [GraphConnection]
    var body: some View {
        let _ = RenderWorkCounters.count(.hoverTopologyBody)
        CompositorTopology(
            hover: hover, nodeIDs: nodeIDs, selectedID: selectedID,
            active: active, running: motion && !reduceMotion, connections: connections
        ).allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct HoverDestination: ViewModifier {
    let destination: GraphHoverDestination
    let selected: Bool
    let active: Bool
    let left: Bool
    func body(content: Content) -> some View {
        let _ = RenderWorkCounters.count(.hoverDestinationBody)
        content.overlay {
            CompositorDestination(
                destination: destination, selected: selected, active: active, left: left
            )
            .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}
