import Foundation
import SQLite3
import Combine

struct ReaderFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Local-only adapter. Databases are opened SQLITE_OPEN_READONLY; logs are never changed.
actor CodexReader {
    struct CachedLog { var path: String; var offset: UInt64; var partial: Data; var observation: LogObservation }
    private var cache: [String: CachedLog] = [:]
    private let home: URL
    init(home: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")) { self.home = home }

    func read() throws -> FleetSnapshot {
        let db = try ReadOnlyDatabase(home.appendingPathComponent("state_5.sqlite").path)
        let membership = try projectMembership(db)
        let rows = try db.query("SELECT id, COALESCE(NULLIF(name, ''), title) AS display_name, rollout_path, updated_at, cwd, project_id FROM threads WHERE archived = 0 AND thread_source IN ('user', 'voice_chat') ORDER BY updated_at DESC")
        let history = try? ReadOnlyDatabase(home.appendingPathComponent("thread_history_1.sqlite").path)
        var notices: [String] = []
        var missions: [Mission] = []
        for row in rows {
            guard let id = row["id"], let path = row["rollout_path"], let name = row["display_name"], !name.isEmpty else { continue }
            let projectID = membership.projectID(threadID: id, explicitID: row["project_id"], cwd: row["cwd"] ?? "")
            let (role, symbol) = Self.identity(name)
            var observation = LogObservation()
            var state: MissionStatus = .unknown
            var sourceLabel = "SESSION LOG"
            do {
                observation = try readLog(id: id, path: path)
                state = observation.status ?? .unknown
            } catch {
                sourceLabel = "SAVED HISTORY · SESSION UNAVAILABLE"
                if let history, let saved = try? savedObservation(id: id, db: history) {
                    observation = saved
                    // A missing session cannot establish current work. Retain only historical text.
                    state = .unknown
                } else { notices.append("\(name): local activity record is unavailable.") }
            }
            let updated = try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
            let date = updated ?? observation.taskTime ?? Date(timeIntervalSince1970: Double(row["updated_at"] ?? "0") ?? 0)
            // A start marker surviving an app crash is not proof that an agent is still running.
            if state == .working && Date().timeIntervalSince(date) > 1800 { state = .unknown }
            let edges = try db.query("SELECT t.id, COALESCE(t.agent_path, t.agent_nickname, t.name, 'Agent') AS display_name, t.rollout_path FROM thread_spawn_edges e JOIN threads t ON t.id=e.child_thread_id WHERE e.parent_thread_id=? AND COALESCE(t.thread_source, '') <> 'guardian_review' ORDER BY t.updated_at DESC", bind: id)
            var agents: [Agent] = []
            for edge in edges {
                guard let aid = edge["id"], let apath = edge["rollout_path"] else { continue }
                let log = try? readLog(id: aid, path: apath, needsTask: false)
                var status = log?.status ?? .unknown
                if status == .working,
                   let attrs = try? FileManager.default.attributesOfItem(atPath: apath),
                   let modified = attrs[.modificationDate] as? Date, Date().timeIntervalSince(modified) > 1800 { status = .unknown }
                agents.append(Agent(id: aid, name: edge["display_name"]?.components(separatedBy: "/").last ?? "Agent", status: status))
            }
            missions.append(Mission(id: id, projectID: projectID, name: name, role: role, symbol: symbol,
                                    task: observation.task ?? "No recent task is available in the local record.",
                                    status: state, updated: date, sourcePath: path, sourceLabel: sourceLabel, agents: agents))
        }
        var projects = membership.projects
        if missions.contains(where: { $0.projectID == "unassigned" }) {
            projects.append(WorkspaceProject(id: "unassigned", name: "Unassigned chats", roots: []))
        }
        return FleetSnapshot(projects: projects, missions: missions, readAt: Date(), notices: notices)
    }

    private func savedObservation(id: String, db: ReadOnlyDatabase) throws -> LogObservation {
        var observation = LogObservation()
        let records = try db.query("SELECT item_json, created_at_ms FROM thread_items WHERE thread_id=? AND item_type='userMessage' ORDER BY created_at_ms DESC LIMIT 30", bind: id)
        for row in records {
            guard let text = row["item_json"], let data = text.data(using: .utf8),
                  let item = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let parts = item["content"] as? [[String: Any]],
                  let task = LogObservation.cleanTask(parts.compactMap { $0["text"] as? String }.joined(separator: "\n")) else { continue }
            observation.task = task
            observation.taskTime = Date(timeIntervalSince1970: (Double(row["created_at_ms"] ?? "0") ?? 0) / 1000)
            break
        }
        return observation
    }

    private func projectMembership(_ db: ReadOnlyDatabase) throws -> ProjectMembership {
        let projectRows = try db.query("SELECT id, name FROM projects ORDER BY position, name")
        let roots = try db.query("SELECT project_id, path FROM project_roots ORDER BY position")
        let projects = projectRows.compactMap { row -> WorkspaceProject? in
            guard let id = row["id"], let name = row["name"] else { return nil }
            return WorkspaceProject(id: id, name: name, roots: roots.filter { $0["project_id"] == id }.compactMap { $0["path"] })
        }
        let statePath = home.appendingPathComponent(".codex-global-state.json")
        var catalog = ProjectMembership(projects: projects)
        guard FileManager.default.fileExists(atPath: statePath.path) else { return catalog }
        guard let data = try? Data(contentsOf: statePath), let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ReaderFailure(message: "Codex project assignments are temporarily unavailable. Retrying shortly.")
        }
        // Desktop still stores legacy project IDs for many existing chats.
        let local = state["local-projects"] as? [String: [String: Any]] ?? [:]
        let mappings = state["app-server-project-id-by-legacy-project-id-by-host"] as? [String: [String: String]] ?? [:]
        let localMapping = mappings["local:" + home.path] ?? [:]
        for (legacyID, project) in local {
            if let native = localMapping[legacyID], projects.contains(where: { $0.id == native }) {
                catalog.aliases[legacyID] = native
            } else if let paths = project["rootPaths"] as? [String],
                      let match = projects.first(where: { !Set($0.roots).isDisjoint(with: paths) }) {
                catalog.aliases[legacyID] = match.id
            }
        }
        let assignments = state["thread-project-assignments"] as? [String: [String: Any]] ?? [:]
        for (thread, assignment) in assignments where assignment["projectKind"] as? String == "local" {
            catalog.assignments[thread] = assignment["projectId"] as? String
        }
        catalog.unassigned = Set(state["projectless-thread-ids"] as? [String] ?? [])
        return catalog
    }

    private static func identity(_ name: String) -> (String, String) {
        switch name {
        case "Xiaomi monitor": return ("PERSONAL SYSTEMS", "cpu")
        case "Coding": return ("ENGINEERING", "chevron.left.forwardslash.chevron.right")
        case "Marketing": return ("GROWTH & STRATEGY", "chart.xyaxis.line")
        case "LinkedIn": return ("VOICE & CONNECTIONS", "person.2.wave.2")
        default: return ("PROJECT CHAT", "bubble.left.and.bubble.right")
        }
    }

    private func readLog(id: String, path: String, needsTask: Bool = true) throws -> LogObservation {
        // Paths come from Codex's database. Restrict reads to the local sessions directories.
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let allowed = ["sessions", "archived_sessions"].map { home.appendingPathComponent($0).resolvingSymlinksInPath().path + "/" }
        guard allowed.contains(where: { url.path.hasPrefix($0) }) else { throw ReaderFailure(message: "Activity file is outside Codex's session directories.") }
        let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
        let size = try file.seekToEnd()
        var entry = cache[id] ?? CachedLog(path: path, offset: 0, partial: Data(), observation: LogObservation())
        if entry.path != path || entry.offset > size { entry = CachedLog(path: path, offset: 0, partial: Data(), observation: LogObservation()) }
        if entry.offset == 0 {
            // Search backward for the newest lifecycle marker and meaningful task. Most files need
            // only one block. A large old history never needs to be loaded into memory all at once.
            var cursor = size
            var suffix = Data()
            var foundStatus = false, foundTask = false
            while cursor > 0 && (!foundStatus || (needsTask && !foundTask)) {
                let start = cursor > 1_048_576 ? cursor - 1_048_576 : 0
                try file.seek(toOffset: start)
                var block = try file.read(upToCount: Int(cursor - start)) ?? Data()
                block.append(suffix)
                let segments = block.split(separator: 10, omittingEmptySubsequences: false)
                // The first segment belongs to the preceding block; never parse half a JSON line.
                suffix = start > 0 ? Data(segments.first ?? Data.SubSequence()) : Data()
                let complete = start > 0 ? segments.dropFirst() : segments[...]
                for part in complete.reversed() {
                    guard let line = String(data: Data(part), encoding: .utf8) else { continue }
                    var single = LogObservation(); single.consume(line)
                    if !foundStatus, let status = single.status { entry.observation.status = status; entry.observation.eventTime = single.eventTime; foundStatus = true }
                    if !foundTask, let task = single.task { entry.observation.task = task; entry.observation.taskTime = single.taskTime; foundTask = true }
                    if foundTask && foundStatus { break }
                }
                cursor = start
            }
            // Retain an incomplete last record for the next poll, rather than losing its prefix.
            try file.seek(toOffset: size > 65536 ? size - 65536 : 0)
            let tail = try file.readToEnd() ?? Data()
            if tail.last != 10 { entry.partial = Data(tail.split(separator: 10, omittingEmptySubsequences: false).last ?? Data.SubSequence()) }
            entry.offset = size
        } else if size > entry.offset {
            try file.seek(toOffset: entry.offset)
            while let next = try file.read(upToCount: 1_048_576), !next.isEmpty {
                entry.partial.append(next)
                while let newline = entry.partial.firstIndex(of: 10) {
                    let line = entry.partial.prefix(upTo: newline)
                    if let string = String(data: line, encoding: .utf8) { entry.observation.consume(string) }
                    entry.partial.removeSubrange(...newline)
                }
                entry.offset += UInt64(next.count)
            }
        }
        cache[id] = entry
        return entry.observation
    }
}

final class ReadOnlyDatabase {
    private var db: OpaquePointer?
    init(_ path: String) throws {
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "database unavailable"
            if let db { sqlite3_close(db) }; db = nil
            throw ReaderFailure(message: "Cannot read local Codex records: \(message)")
        }
        sqlite3_busy_timeout(db, 700)
    }
    deinit { sqlite3_close(db) }
    func query(_ sql: String, bind: String? = nil) throws -> [[String: String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ReaderFailure(message: "Codex's local record format has changed. This adapter needs an update.")
        }
        defer { sqlite3_finalize(statement) }
        if let bind { _ = bind.withCString { sqlite3_bind_text(statement, 1, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) } }
        var result: [[String: String]] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            var row: [String: String] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                if let text = sqlite3_column_text(statement, index) { row[String(cString: sqlite3_column_name(statement, index))] = String(cString: text) }
            }
            result.append(row); status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw ReaderFailure(message: "Local Codex records are busy. Retrying shortly.") }
        return result
    }
}

@MainActor final class FleetStore: ObservableObject {
    @Published var snapshot: FleetSnapshot?
    @Published var error: String?
    @Published var refreshing = false
    private let reader = CodexReader()
    func refresh() async {
        guard !refreshing else { return }
        refreshing = true; defer { refreshing = false }
        do { snapshot = try await reader.read(); error = nil }
        catch { self.error = error.localizedDescription }
    }
}
