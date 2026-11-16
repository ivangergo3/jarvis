import Combine
import Foundation
import JarvisDomain

/// App-owned presentation state. Only the source actor performs workspace I/O.
@MainActor final class FleetStore: ObservableObject {
    @Published private(set) var snapshot: FleetSnapshot?
    @Published private(set) var error: String?
    private(set) var refreshing = false
    private let source: any WorkspaceSource

    init(source: any WorkspaceSource) { self.source = source }

    /// Single flight, including while a cancelled caller's non-cooperative read finishes.
    /// SwiftUI cancels the polling caller on task replacement/window destruction;
    /// a cancelled response or error must not change the displayed snapshot.
    func refresh() async {
        guard !refreshing, !Task.isCancelled else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let next = try await source.read()
            guard !Task.isCancelled else { return }
            if snapshot?.hasSameDisplayContent(as: next) != true { snapshot = next }
            if error != nil { error = nil }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
