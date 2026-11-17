import Combine

/// Hover is local decoration: it must not republish dashboard or conversation state.
@MainActor final class GraphHoverState: ObservableObject {
    @Published private(set) var nodeID: String?
    func update(_ id: String, inside: Bool) {
        if inside {
            if nodeID != id { nodeID = id }
        } else if nodeID == id {
            nodeID = nil
        }
    }
    func clear() { if nodeID != nil { nodeID = nil } }
}
