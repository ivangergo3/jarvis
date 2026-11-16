import Combine
import Foundation

@MainActor final class DashboardState: ObservableObject {
    private let preferences: UserDefaults?
    @Published var selection: String? {
        didSet { preferences?.set(selection, forKey: "selectedChat") }
    }
    @Published var projectID: String? {
        didSet { preferences?.set(projectID ?? "__all__", forKey: "selectedProject") }
    }
    @Published var tab = "Overview"
    @Published var motion = true
    @Published var board = false
    let graphHover = GraphHoverState()
    @Published var conversationVisible = true
    @Published var globalSettingsVisible = false
    @Published var projectPickerVisible = false
    @Published var refreshInterval: RefreshInterval = .normal {
        didSet {
            preferences?.set(refreshInterval.rawValue, forKey: "refreshIntervalSeconds")
        }
    }
    init(preferences: UserDefaults? = .standard) {
        self.preferences = preferences
        refreshInterval = RefreshInterval.restoring(
            preferences?.integer(forKey: "refreshIntervalSeconds") ?? 0)
        selection = preferences?.string(forKey: "selectedChat")
        let stored = preferences?.string(forKey: "selectedProject")
        projectID = stored == "__all__" ? nil : stored
    }
}
