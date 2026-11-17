import Combine

/// Hover is local decoration: it must not republish dashboard or conversation state.
@MainActor final class GraphHoverState: ObservableObject {
    @Published private(set) var nodeID: String?
    private struct WeakDestination {
        weak var value: GraphHoverDestination?
    }
    private var destinations: [String: WeakDestination] = [:]

    /// The mounted modifier owns this state. Navigation must not retain old cards.
    func destination(for id: String) -> GraphHoverDestination {
        if let state = destinations[id]?.value { return state }
        destinations = destinations.filter { $0.value.value != nil }
        let state = GraphHoverDestination(highlighted: nodeID == id)
        destinations[id] = WeakDestination(value: state)
        return state
    }

    func update(_ id: String, inside: Bool) {
        if inside {
            setNode(id)
        } else if nodeID == id {
            setNode(nil)
        }
    }
    func clear() { setNode(nil) }

    private func setNode(_ next: String?) {
        guard next != nodeID else { return }
        if let previous = nodeID { destinations[previous]?.value?.setHighlighted(false) }
        if let next { destinations[next]?.value?.setHighlighted(true) }
        nodeID = next
    }
}

@MainActor final class GraphHoverDestination: ObservableObject {
    @Published private(set) var highlighted: Bool
    init(highlighted: Bool) { self.highlighted = highlighted }
    fileprivate func setHighlighted(_ value: Bool) {
        if highlighted != value { highlighted = value }
    }
}
