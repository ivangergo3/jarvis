import Combine

@MainActor final class PerformanceProgress: ObservableObject {
    @Published var stage = "Preparing synthetic performance recording"
    @Published var cursorFinished = false
}

enum RenderWork: String, Codable, CaseIterable {
    case dashboardBody, conversationBody, graphLayout, cardFactory
    case hoverTopologyBody, hoverDestinationBody, connectorRebuild, nativeDraw
    case dashboardPublication, conversationPublication, hoverPublication
    case physicalHoverCallback
}

@MainActor enum RenderWorkCounters {
    static var onCount: ((RenderWork) -> Void)?
    static var onDashboard: ((String?, Bool) -> Void)?
    static func count(_ work: RenderWork) { onCount?(work) }
    static func dashboardEvaluated(project: String?, populated: Bool) {
        onDashboard?(project, populated)
    }
}
