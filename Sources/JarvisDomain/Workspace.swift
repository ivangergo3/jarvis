import Foundation

public enum MissionStatus: String, Codable, Sendable {
    case working, standby, interrupted, unknown
    public var label: String {
        switch self {
        case .working: return "IN PROGRESS"
        case .standby: return "STANDBY"
        case .interrupted: return "INTERRUPTED"
        case .unknown: return "UNKNOWN"
        }
    }
}

public struct Mission: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let projectID: String
    public let name: String
    public let role: String
    public let symbol: String
    public let task: String
    public let status: MissionStatus
    public let updated: Date
    public let sourcePath: String
    public let sourceLabel: String
    public var agents: [Agent]
    public var sidebarPosition: Int?

    public init(
        id: String, projectID: String, name: String, role: String, symbol: String,
        task: String, status: MissionStatus, updated: Date, sourcePath: String,
        sourceLabel: String, agents: [Agent] = [], sidebarPosition: Int? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.role = role
        self.symbol = symbol
        self.task = task
        self.status = status
        self.updated = updated
        self.sourcePath = sourcePath
        self.sourceLabel = sourceLabel
        self.agents = agents
        self.sidebarPosition = sidebarPosition
    }
}

/// Navigation must not follow activity timestamps or transient working status.
public enum MissionNavigation {
    public static func ordered(_ missions: [Mission]) -> [Mission] {
        missions.sorted {
            let a = $0.sidebarPosition ?? Int.max
            let b = $1.sidebarPosition ?? Int.max
            if a != b { return a < b }
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }
}

public struct Agent: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let status: MissionStatus

    public init(id: String, name: String, status: MissionStatus) {
        self.id = id
        self.name = name
        self.status = status
    }
}

public struct FleetSnapshot: Codable, Sendable {
    public let projects: [WorkspaceProject]
    public let missions: [Mission]
    public let readAt: Date
    public let notices: [String]

    public init(projects: [WorkspaceProject], missions: [Mission], readAt: Date, notices: [String])
    {
        self.projects = projects
        self.missions = missions
        self.readAt = readAt
        self.notices = notices
    }

    public func hasSameDisplayContent(as other: FleetSnapshot) -> Bool {
        projects == other.projects && missions == other.missions && notices == other.notices
    }
    public var activeCount: Int { missions.filter { $0.status == .working }.count }
    public var activeAgents: Int {
        missions.flatMap(\.agents).filter { $0.status == .working }.count
    }
}

public struct WorkspaceProject: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let roots: [String]
    public var isUnassigned: Bool { id == "unassigned" }

    public init(id: String, name: String, roots: [String]) {
        self.id = id
        self.name = name
        self.roots = roots
    }
}

/// Resolves modern IDs, migrated project IDs, explicit assignments and nested roots.
public struct ProjectMembership: Sendable {
    public let projects: [WorkspaceProject]
    public var aliases: [String: String]
    public var assignments: [String: String]
    public var unassigned: Set<String>
    public var threadOrders: [String: [String]]

    public init(
        projects: [WorkspaceProject], aliases: [String: String] = [:],
        assignments: [String: String] = [:], unassigned: Set<String> = [],
        threadOrders: [String: [String]] = [:]
    ) {
        self.projects = projects
        self.aliases = aliases
        self.assignments = assignments
        self.unassigned = unassigned
        self.threadOrders = threadOrders
    }

    public func projectID(threadID: String, explicitID: String?, cwd: String) -> String {
        if unassigned.contains(threadID) { return "unassigned" }
        for candidate in [explicitID, assignments[threadID]].compactMap({ $0 }) {
            let id = aliases[candidate] ?? candidate
            if projects.contains(where: { $0.id == id }) { return id }
        }
        // Longest root wins, with a path separator boundary: /work/app is not /work/apple.
        let path = URL(fileURLWithPath: cwd).standardizedFileURL.path
        return projects.flatMap { project in
            project.roots.map { (project.id, URL(fileURLWithPath: $0).standardizedFileURL.path) }
        }
        .filter { path == $0.1 || path.hasPrefix($0.1 + "/") }
        .max(by: { $0.1.count < $1.1.count })?.0 ?? "unassigned"
    }
}

/// Shared text policy; record decoding belongs to the workspace adapter.
public enum TaskText {
    public static func cleanTask(_ text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let wrappers = [
            "<environment_context>", "<heartbeat>", "<send_user_message_question_reply>",
            "<external_codex_apps_open_page>", "<codex", "<permissions", "<skill>",
            "<skills_instructions>",
        ]
        guard !wrappers.contains(where: { text.hasPrefix($0) }) else { return nil }
        if text.contains("<source>transcript_tail_flush</source>") { return nil }
        if text.hasPrefix("<realtime_delegation>"),
            let a = text.range(of: "<input>"), let b = text.range(of: "</input>")
        {
            return String(text[a.upperBound..<b.lowerBound])
        }
        return String(text.prefix(8000))
    }
}

public protocol WorkspaceSource: Sendable {
    func read() async throws -> FleetSnapshot
}
