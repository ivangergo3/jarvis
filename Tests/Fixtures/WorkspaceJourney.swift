import Foundation
import SQLite3

// Standalone native journey setup. Only creates synthetic records in an empty owned directory.
guard
    CommandLine.arguments.count == 2
        || (CommandLine.arguments.count == 3 && CommandLine.arguments[2] == "--performance")
else { exit(64) }
let performance = CommandLine.arguments.count == 3
let home = URL(fileURLWithPath: CommandLine.arguments[1])
guard try FileManager.default.contentsOfDirectory(atPath: home.path).isEmpty else {
    FileHandle.standardError.write(Data("Fixture directory must be empty.\n".utf8))
    exit(64)
}
let sessions = home.appendingPathComponent("sessions")
try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
var database: OpaquePointer?
guard sqlite3_open(home.appendingPathComponent("state_5.sqlite").path, &database) == SQLITE_OK,
    let database
else { exit(1) }
defer { sqlite3_close(database) }
func execute(_ sql: String) {
    guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { exit(1) }
}
execute(
    """
    CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT, position INTEGER);
    CREATE TABLE project_roots (project_id TEXT, path TEXT, position INTEGER);
    CREATE TABLE threads (id TEXT PRIMARY KEY, name TEXT, title TEXT, rollout_path TEXT,
        updated_at INTEGER, cwd TEXT, project_id TEXT, archived INTEGER,
        thread_source TEXT, agent_path TEXT, agent_nickname TEXT);
    CREATE TABLE thread_spawn_edges (parent_thread_id TEXT, child_thread_id TEXT);
    """)
var records = [
    ("alpha-chat", "alpha", "Plan a synthetic launch", "task_started"),
    ("beta-chat", "beta", "Review a synthetic report", "task_complete"),
]
if performance {
    records = []
    for (position, count) in [0, 1, 4, 20, 100].enumerated() {
        execute(
            "INSERT INTO projects VALUES ('perf-\(count)', 'Performance \(count) chats', \(position))"
        )
        execute("INSERT INTO project_roots VALUES ('perf-\(count)', '/synthetic/perf-\(count)', 0)")
        for index in 0..<count {
            records.append(
                (
                    "perf-\(count)-chat-\(index)", "perf-\(count)", "Synthetic chat \(index)",
                    index.isMultiple(of: 3) ? "task_started" : "task_complete"
                ))
        }
    }
} else {
    execute(
        "INSERT INTO projects VALUES ('alpha', 'Fixture Alpha', 0), ('beta', 'Fixture Beta', 1)")
    execute(
        "INSERT INTO project_roots VALUES ('alpha', '/synthetic/alpha', 0), ('beta', '/synthetic/beta', 0)"
    )
}
var logBytes = 0
for (id, project, name, state) in records {
    let log = sessions.appendingPathComponent(id + ".jsonl")
    let contents =
        (performance
            ? String(
                repeating:
                    "{\"type\":\"event_msg\",\"payload\":{\"type\":\"unrelated_fixture_event\",\"value\":7}}\n",
                count: 1_000) : "") + """
            {"type":"response_item","payload":{"type":"message","role":"user","content":[{"text":"Synthetic task for \(project)"}]}}
            {"type":"event_msg","payload":{"type":"\(state)"}}

            """
    try contents.write(to: log, atomically: true, encoding: .utf8)
    logBytes += contents.utf8.count
    // All interpolated values are our fixed synthetic constants; only the owned path is escaped.
    let path = log.path.replacingOccurrences(of: "'", with: "''")
    execute(
        "INSERT INTO threads VALUES ('\(id)', '\(name)', '', '\(path)', 0, '/synthetic/\(project)', '\(project)', 0, 'user', NULL, NULL)"
    )
}
if performance {
    let metadata = [
        "projects": 5, "chats": records.count, "eventsPerChat": 1_002, "logBytes": logBytes,
    ]
    try JSONEncoder().encode(metadata).write(
        to: home.appendingPathComponent("performance-fixture.json"))
}
print(home.path)
