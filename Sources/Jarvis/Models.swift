import Foundation

enum MissionStatus: String, Codable {
    case working, standby, interrupted, unknown
    var label: String {
        switch self {
        case .working: return "IN PROGRESS"
        case .standby: return "STANDBY"
        case .interrupted: return "INTERRUPTED"
        case .unknown: return "UNKNOWN"
        }
    }
}

struct Mission: Identifiable, Codable, Equatable {
    let id: String
    let projectID: String
    let name: String
    let role: String
    let symbol: String
    let task: String
    let status: MissionStatus
    let updated: Date
    let sourcePath: String
    let sourceLabel: String
    var agents: [Agent] = []
    var sidebarPosition: Int? = nil
}

/// Navigation must not follow activity timestamps or transient working status.
enum MissionNavigation {
    static func ordered(_ missions: [Mission]) -> [Mission] {
        missions.sorted {
            let a = $0.sidebarPosition ?? Int.max, b = $1.sidebarPosition ?? Int.max
            if a != b { return a < b }
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }
}

struct Agent: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let status: MissionStatus
}

struct FleetSnapshot: Codable {
    let projects: [WorkspaceProject]
    let missions: [Mission]
    let readAt: Date
    let notices: [String]
    func hasSameDisplayContent(as other: FleetSnapshot) -> Bool {
        projects == other.projects && missions == other.missions && notices == other.notices
    }
    var activeCount: Int { missions.filter { $0.status == .working }.count }
    var activeAgents: Int { missions.flatMap(\.agents).filter { $0.status == .working }.count }
}

struct WorkspaceProject: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let roots: [String]
    var isUnassigned: Bool { id == "unassigned" }
}

/// Resolves modern IDs, migrated project IDs, explicit assignments and nested roots.
struct ProjectMembership {
    let projects: [WorkspaceProject]
    var aliases: [String: String] = [:]
    var assignments: [String: String] = [:]
    var unassigned: Set<String> = []
    var threadOrders: [String: [String]] = [:]

    func projectID(threadID: String, explicitID: String?, cwd: String) -> String {
        if unassigned.contains(threadID) { return "unassigned" }
        for candidate in [explicitID, assignments[threadID]].compactMap({ $0 }) {
            let id = aliases[candidate] ?? candidate
            if projects.contains(where: { $0.id == id }) { return id }
        }
        // Longest root wins, with a path separator boundary: /work/app is not /work/apple.
        let path = URL(fileURLWithPath: cwd).standardizedFileURL.path
        return projects.flatMap { project in project.roots.map { (project.id, URL(fileURLWithPath: $0).standardizedFileURL.path) } }
            .filter { path == $0.1 || path.hasPrefix($0.1 + "/") }
            .max(by: { $0.1.count < $1.1.count })?.0 ?? "unassigned"
    }
}

struct LogObservation {
    var status: MissionStatus?
    var eventTime: Date?
    var task: String?
    var taskTime: Date?

    mutating func consume(_ line: String) {
        // Skip large tool outputs and reasoning before decoding JSON.
        guard line.contains("\"task_started\"") || line.contains("\"task_complete\"") ||
            line.contains("\"task_aborted\"") || line.contains("\"turn_aborted\"") ||
            (line.contains("\"message\"") && line.contains("\"user\"")) else { return }
        guard let data = line.data(using: .utf8),
              let record = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = record["payload"] as? [String: Any] else { return }
        let type = payload["type"] as? String ?? ""
        let time = Self.date(record["timestamp"] as? String)
        if record["type"] as? String == "event_msg" {
            let state: MissionStatus?
            switch type {
            case "task_started": state = .working
            case "task_complete": state = .standby
            case "task_aborted", "turn_aborted": state = .interrupted
            default: state = nil
            }
            if let state { status = state; eventTime = time }
        }
        if record["type"] as? String == "response_item", type == "message",
           payload["role"] as? String == "user", let content = payload["content"] as? [[String: Any]] {
            let text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            if let clean = Self.cleanTask(text) { task = clean; taskTime = time }
        }
    }

    static func cleanTask(_ text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let wrappers = ["<environment_context>", "<heartbeat>", "<send_user_message_question_reply>",
                        "<external_codex_apps_open_page>", "<codex", "<permissions", "<skill>", "<skills_instructions>"]
        guard !wrappers.contains(where: { text.hasPrefix($0) }) else { return nil }
        if text.contains("<source>transcript_tail_flush</source>") { return nil }
        if text.hasPrefix("<realtime_delegation>"),
           let a = text.range(of: "<input>"), let b = text.range(of: "</input>") {
            return String(text[a.upperBound..<b.lowerBound])
        }
        return String(text.prefix(8000))
    }

    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        return fractional.date(from: value) ?? whole.date(from: value)
    }
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let whole = ISO8601DateFormatter()
}
