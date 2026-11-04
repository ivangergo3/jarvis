import Foundation
import SQLite3

/// Every database and log belongs to this disposable directory, never the user's Codex home.
final class SessionFixture {
    let home: URL

    init() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("jarvis-tests-\(UUID())")
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent("sessions"), withIntermediateDirectories: true
        )
        try execute("""
            CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT, position INTEGER);
            CREATE TABLE project_roots (project_id TEXT, path TEXT, position INTEGER);
            CREATE TABLE threads (
                id TEXT PRIMARY KEY, name TEXT, title TEXT, rollout_path TEXT,
                updated_at INTEGER, cwd TEXT, project_id TEXT, archived INTEGER,
                thread_source TEXT, agent_path TEXT, agent_nickname TEXT
            );
            CREATE TABLE thread_spawn_edges (parent_thread_id TEXT, child_thread_id TEXT);
            INSERT INTO projects VALUES ('demo', 'Demo project', 0);
            INSERT INTO project_roots VALUES ('demo', '/work/demo', 0);
            """)
    }

    deinit { try? FileManager.default.removeItem(at: home) }

    static func quote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "''") + "'" }

    static func message(_ text: String, role: String = "user") -> String {
        // Internal fixture invariant: this dictionary contains only JSON-serializable strings/arrays.
        let data = try! JSONSerialization.data(withJSONObject: [
            "type": "response_item",
            "payload": ["type": "message", "role": role, "content": [["text": text]]],
        ])
        return String(decoding: data, as: UTF8.self)
    }

    func execute(_ sql: String, database: String = "state_5.sqlite") throws {
        var db: OpaquePointer?
        guard sqlite3_open(home.appendingPathComponent(database).path, &db) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            throw FixtureError(message: "Cannot create fixture database")
        }
        defer { sqlite3_close(db) }
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw FixtureError(message: String(cString: sqlite3_errmsg(db)))
        }
    }

    @discardableResult
    func addThread(
        _ id: String = "chat", source: String = "user", archived: Bool = false,
        cwd: String = "/work/demo", projectID: String? = nil,
        log: String = "{\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\"}}\n"
    ) throws -> URL {
        let file = home.appendingPathComponent("sessions/\(id).jsonl")
        try Data(log.utf8).write(to: file)
        let q = Self.quote
        try execute("""
            INSERT INTO threads VALUES (
                \(q(id)), 'Same display name', 'Fallback title', \(q(file.path)),
                0, \(q(cwd)), \(projectID.map(q) ?? "NULL"), \(archived ? 1 : 0),
                \(q(source)), NULL, NULL
            );
            """)
        return file
    }

    func append(_ text: String, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }

    func setAssignments(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        try data.write(to: home.appendingPathComponent(".codex-global-state.json"))
    }
}

struct FixtureError: Error { let message: String }
