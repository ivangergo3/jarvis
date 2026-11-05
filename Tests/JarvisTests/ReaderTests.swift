import Foundation
import Testing
@testable import Jarvis

@Suite("Read-only Codex adapter")
struct ReaderTests {
    @Test func missingDatabaseIsNotCreated() throws {
        let fixture = try SessionFixture()
        let missing = fixture.home.appendingPathComponent("absent.sqlite")
        #expect(throws: ReaderFailure.self) { try ReadOnlyDatabase(missing.path) }
        #expect(!FileManager.default.fileExists(atPath: missing.path))
    }

    @Test func databaseRejectsWritesAndBindsValuesLiterally() throws {
        let fixture = try SessionFixture()
        let before = try Data(contentsOf: fixture.home.appendingPathComponent("state_5.sqlite"))
        let db = try ReadOnlyDatabase(fixture.home.appendingPathComponent("state_5.sqlite").path)
        #expect(try db.query("SELECT id FROM projects WHERE id=?", bind: "demo").count == 1)
        #expect(try db.query("SELECT id FROM projects WHERE id=?", bind: "' OR 1=1 --").isEmpty)
        #expect(throws: ReaderFailure.self) { try db.query("DELETE FROM projects") }
        #expect(throws: ReaderFailure.self) { try db.query("SELECT * FROM unknown_table") }
        #expect(try Data(contentsOf: fixture.home.appendingPathComponent("state_5.sqlite")) == before)
    }

    @Test func discoversOnlyVisibleChatsAndRecordedNonReviewerAgents() async throws {
        let fixture = try SessionFixture()
        try fixture.addThread("first")
        try fixture.addThread("voice", source: "voice_chat")
        try fixture.addThread("archived", archived: true)
        try fixture.addThread("child", source: "subagent")
        try fixture.addThread("reviewer", source: "guardian_review")
        try fixture.execute("""
            INSERT INTO thread_spawn_edges VALUES ('first', 'child');
            INSERT INTO thread_spawn_edges VALUES ('first', 'reviewer');
            """)
        let reader = CodexReader(home: fixture.home)
        let snapshot = try await reader.read()
        #expect(Set(snapshot.missions.map(\.id)) == ["first", "voice"])
        #expect(snapshot.projects.map(\.id) == ["demo"])
        #expect(snapshot.missions.allSatisfy { $0.projectID == "demo" })
        #expect(snapshot.missions.first { $0.id == "first" }?.agents.map(\.id) == ["child"])
        #expect(snapshot.activeCount == 2)
        #expect(snapshot.activeAgents == 1)
        let second = try await reader.read()
        #expect(Set(second.missions.map(\.id)) == Set(snapshot.missions.map(\.id)))
    }

    @Test func desktopAssignmentsOverrideRootsAndKeepUnassignedSelectable() async throws {
        let fixture = try SessionFixture()
        try fixture.addThread("moved", cwd: "/elsewhere")
        try fixture.addThread("loose", projectID: "demo")
        try fixture.setAssignments([
            "local-projects": ["legacy": ["rootPaths": ["/work/demo"]]],
            "thread-project-assignments": ["moved": ["projectKind": "local", "projectId": "legacy"]],
            "projectless-thread-ids": ["loose"],
        ])
        let snapshot = try await CodexReader(home: fixture.home).read()
        #expect(snapshot.missions.first { $0.id == "moved" }?.projectID == "demo")
        #expect(snapshot.missions.first { $0.id == "loose" }?.projectID == "unassigned")
        #expect(Set(snapshot.projects.map(\.id)) == ["demo", "unassigned"])
    }

    @Test func sidebarFollowsSavedOrderAcrossActivityChangesAndLegacyProjectIDs() async throws {
        let fixture = try SessionFixture()
        for id in ["coding", "jarvis", "marketing", "new"] { try fixture.addThread(id) }
        try fixture.setAssignments([
            "local-projects": ["legacy": ["rootPaths": ["/work/demo"]]],
            "sidebar-project-thread-orders": ["legacy": ["threadIds": ["archived-or-moved", "marketing", "jarvis", "coding", "coding"]]],
        ])
        let reader = CodexReader(home: fixture.home)
        let first = try await reader.read()
        #expect(MissionNavigation.ordered(first.missions).map(\.id) == ["marketing", "jarvis", "coding", "new"])
        try fixture.execute("UPDATE threads SET updated_at=999999999 WHERE id='coding'")
        let next = try await reader.read()
        #expect(MissionNavigation.ordered(next.missions).map(\.id) == ["marketing", "jarvis", "coding", "new"])
        // A deliberate Codex reorder is reflected on the next refresh.
        try fixture.setAssignments(["sidebar-project-thread-orders": ["demo": ["threadIds": ["coding", "marketing", "jarvis"]]]])
        let reordered = try await reader.read()
        #expect(MissionNavigation.ordered(reordered.missions).map(\.id) == ["coding", "marketing", "jarvis", "new"])
    }

    @Test func sidebarFallbackAndMigratedOrderAreDeterministic() async throws {
        let fixture = try SessionFixture()
        for id in ["b", "a", "z"] { try fixture.addThread(id) }
        try fixture.execute("UPDATE threads SET name='Alpha' WHERE id='z'")
        let reader = CodexReader(home: fixture.home)
        let initial = try await reader.read()
        #expect(MissionNavigation.ordered(initial.missions).map(\.id) == ["z", "a", "b"])
        try fixture.setAssignments([
            "local-projects": ["legacy": ["rootPaths": ["/work/demo"]]],
            "sidebar-project-thread-orders": [
                "legacy": ["threadIds": ["a", "b", "z"]],
                "demo": ["threadIds": ["b", "z", "a"]],
            ],
        ])
        let migrated = try await reader.read()
        #expect(MissionNavigation.ordered(migrated.missions).map(\.id) == ["b", "z", "a"])
    }

    @Test func incrementalReadsKeepPartialRecordsAndResetAfterTruncation() async throws {
        let fixture = try SessionFixture()
        let file = try fixture.addThread(log: SessionFixture.message("Original request") + "\n")
        let reader = CodexReader(home: fixture.home)
        #expect(try await reader.read().missions.first?.task == "Original request")
        let next = SessionFixture.message("Next request 🦾")
        let split = next.index(next.startIndex, offsetBy: next.count / 2)
        try fixture.append(String(next[..<split]), to: file)
        #expect(try await reader.read().missions.first?.task == "Original request")
        try fixture.append(String(next[split...]) + "\n", to: file)
        #expect(try await reader.read().missions.first?.task == "Next request 🦾")
        try Data((SessionFixture.message("Reset") + "\n").utf8).write(to: file)
        #expect(try await reader.read().missions.first?.task == "Reset")
    }

    @Test func initialPartialRecordIsCompletedOnNextPoll() async throws {
        let fixture = try SessionFixture()
        let record = SessionFixture.message("Completed later")
        let split = record.index(record.startIndex, offsetBy: record.count / 2)
        let file = try fixture.addThread(log: String(record[..<split]))
        let reader = CodexReader(home: fixture.home)
        #expect(try await reader.read().missions.first?.status == .unknown)
        try fixture.append(String(record[split...]) + "\n", to: file)
        #expect(try await reader.read().missions.first?.task == "Completed later")
    }

    @Test func missingLogUsesSavedTextWithoutClaimingActiveWork() async throws {
        let fixture = try SessionFixture()
        let file = try fixture.addThread()
        try FileManager.default.removeItem(at: file)
        let saved = "{\"content\":[{\"text\":\"Recovered request\"}]}"
        try fixture.execute("""
            CREATE TABLE thread_items (thread_id TEXT, item_type TEXT, item_json TEXT, created_at_ms INTEGER);
            INSERT INTO thread_items VALUES ('chat', 'userMessage', \(SessionFixture.quote(saved)), 1000);
            """, database: "thread_history_1.sqlite")
        let mission = try #require(try await CodexReader(home: fixture.home).read().missions.first)
        #expect(mission.task == "Recovered request")
        #expect(mission.status == .unknown)
        #expect(mission.sourceLabel.contains("SAVED HISTORY"))
    }

    @Test func staleStartMarkerDoesNotClaimCurrentWork() async throws {
        let fixture = try SessionFixture()
        let file = try fixture.addThread()
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -3600)], ofItemAtPath: file.path
        )
        #expect(try await CodexReader(home: fixture.home).read().missions.first?.status == .unknown)
    }

    @Test func sessionSymlinkCannotReadOutsideAllowedDirectories() async throws {
        let fixture = try SessionFixture()
        let file = try fixture.addThread()
        let outside = fixture.home.appendingPathComponent("outside.jsonl")
        try Data((SessionFixture.message("Must not be read") + "\n").utf8).write(to: outside)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside)
        let snapshot = try await CodexReader(home: fixture.home).read()
        #expect(snapshot.missions.first?.status == .unknown)
        #expect(snapshot.missions.first?.task != "Must not be read")
        #expect(!snapshot.notices.isEmpty)
    }

    @Test func corruptCatalogAndUnsupportedSchemaFailExplicitly() async throws {
        let fixture = try SessionFixture()
        try Data("{unfinished".utf8).write(to: fixture.home.appendingPathComponent(".codex-global-state.json"))
        await #expect(throws: ReaderFailure.self) { try await CodexReader(home: fixture.home).read() }
        try FileManager.default.removeItem(at: fixture.home.appendingPathComponent(".codex-global-state.json"))
        try fixture.execute("DROP TABLE threads")
        await #expect(throws: ReaderFailure.self) { try await CodexReader(home: fixture.home).read() }
    }
}
