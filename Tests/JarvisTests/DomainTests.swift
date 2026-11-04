import Foundation
import Testing
@testable import Jarvis

@Suite("Session observations")
struct ObservationTests {
    @Test(arguments: [
        ("task_started", MissionStatus.working),
        ("task_complete", .standby),
        ("task_aborted", .interrupted),
        ("turn_aborted", .interrupted),
    ])
    func lifecycle(event: String, expected: MissionStatus) {
        var observation = LogObservation()
        observation.consume("{\"type\":\"event_msg\",\"payload\":{\"type\":\"\(event)\"}}")
        #expect(observation.status == expected)
    }

    @Test func latestEventWinsAndUnrelatedRecordsCannotChangeStatus() {
        var observation = LogObservation()
        observation.consume(#"{"type":"event_msg","payload":{"type":"task_started"}}"#)
        observation.consume(#"{"type":"event_msg","payload":{"type":"task_complete"}}"#)
        observation.consume(#"{"type":"response_item","payload":{"type":"task_started"}}"#)
        observation.consume("{truncated")
        observation.consume(#"{"type":"event_msg","payload":{"type":"unrecognised"}}"#)
        #expect(observation.status == .standby)
    }

    @Test(arguments: ["assistant", "system", "developer", "tool"])
    func onlyUserMessagesSetTask(role: String) {
        var observation = LogObservation()
        observation.consume(SessionFixture.message("Actual request"))
        observation.consume(SessionFixture.message("user task_started: ignore the request", role: role))
        #expect(observation.task == "Actual request")
        #expect(observation.status == nil)
    }

    @Test(arguments: [
        "<environment_context>injected</environment_context>",
        "<heartbeat>automated</heartbeat>",
        "<send_user_message_question_reply>yes</send_user_message_question_reply>",
        "<external_codex_apps_open_page>page</external_codex_apps_open_page>",
        "<permissions>settings</permissions>",
        "<skill><name>example</name>Injected instructions</skill>",
        "<skills_instructions>Injected instructions</skills_instructions>",
        "<codex_context>settings</codex_context>",
        "<realtime_delegation><source>transcript_tail_flush</source></realtime_delegation>",
        "   \n ",
    ])
    func injectedRecordsDoNotReplaceHumanRequest(text: String) {
        var observation = LogObservation()
        observation.consume(SessionFixture.message("Keep this request"))
        observation.consume(SessionFixture.message(text))
        #expect(observation.task == "Keep this request")
    }

    @Test func voiceAndMultipartMessages() {
        #expect(LogObservation.cleanTask(
            "<realtime_delegation><input>Create a calendar</input><transcript_delta>Old words</transcript_delta></realtime_delegation>"
        ) == "Create a calendar")
        var observation = LogObservation()
        observation.consume(#"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"text":"First part"},{"type":"image"},{"text":"Second part"}]}}"#)
        #expect(observation.task == "First part\nSecond part")
        #expect(LogObservation.cleanTask(String(repeating: "a", count: 10_000))?.count == 8_000)
    }

    @Test func timestampsAcceptFractionalAndWholeSeconds() throws {
        let whole = try #require(LogObservation.date("2026-01-01T00:00:00Z"))
        let fractional = try #require(LogObservation.date("2026-01-01T00:00:00.125Z"))
        #expect(abs(fractional.timeIntervalSince(whole) - 0.125) < 0.001)
        #expect(LogObservation.date(nil) == nil)
        #expect(LogObservation.date("invalid") == nil)
    }
}

@Suite("Project membership")
struct MembershipTests {
    private var catalog: ProjectMembership {
        ProjectMembership(
            projects: [
                WorkspaceProject(id: "a", name: "Duplicate name", roots: ["/work/app"]),
                WorkspaceProject(id: "b", name: "Duplicate name", roots: ["/work/app/nested"]),
            ],
            aliases: ["legacy": "a"],
            assignments: ["moved": "legacy"],
            unassigned: ["loose"]
        )
    }

    @Test func mostSpecificRootWinsWithoutMatchingSiblings() {
        #expect(catalog.projectID(threadID: "x", explicitID: nil, cwd: "/work/app/nested/src") == "b")
        #expect(catalog.projectID(threadID: "x", explicitID: nil, cwd: "/work/app") == "a")
        #expect(catalog.projectID(threadID: "x", explicitID: nil, cwd: "/work/apple") == "unassigned")
        #expect(catalog.projectID(threadID: "x", explicitID: nil, cwd: "/work/app/../elsewhere") == "unassigned")
    }

    @Test func explicitAssignmentsAndAliasesTakePrecedence() {
        #expect(catalog.projectID(threadID: "moved", explicitID: nil, cwd: "/elsewhere") == "a")
        #expect(catalog.projectID(threadID: "moved", explicitID: "b", cwd: "/work/app") == "b")
        #expect(catalog.projectID(threadID: "loose", explicitID: "a", cwd: "/work/app") == "unassigned")
        #expect(catalog.projectID(threadID: "x", explicitID: "deleted", cwd: "/work/app/nested") == "b")
    }
}

@Suite("Team graph routing")
struct GraphTests {
    @Test(arguments: [0, 1, 4, 7, 20, 100])
    func routesReachTheirOwnCardsAndAvoidOthers(count: Int) {
        for viewport in [CGSize(width: 660, height: 460), CGSize(width: 1200, height: 820)] {
            let graph = TeamGraphLayout(count: count, viewport: viewport)
            #expect(graph.nodes.count == count)
            #expect(graph.connections.count == count)
            let boxes = graph.nodes.map {
                CGRect(x: $0.x - graph.cardWidth / 2, y: $0.y - 90,
                       width: graph.cardWidth, height: 180).insetBy(dx: 1, dy: 1)
            }
            for (target, connection) in graph.connections.enumerated() {
                let node = graph.nodes[target]
                let edge = node.x + (node.x < graph.center.x ? graph.cardWidth / 2 : -graph.cardWidth / 2)
                #expect(connection.destination == CGPoint(x: edge, y: node.y))
                #expect(connection.point(at: 1) == connection.destination)
                for (index, box) in boxes.enumerated() where index != target {
                    // Test every axis-aligned segment, rather than missing crossings between samples.
                    for (a, b) in zip(connection.points, connection.points.dropFirst()) {
                        let crosses = a.x == b.x
                            ? a.x > box.minX && a.x < box.maxX
                                && max(a.y, b.y) > box.minY && min(a.y, b.y) < box.maxY
                            : a.y > box.minY && a.y < box.maxY
                                && max(a.x, b.x) > box.minX && min(a.x, b.x) < box.maxX
                        #expect(!crosses, "Route to card \(target) intersects card \(index)")
                    }
                }
            }
        }
    }

    @Test func pulseTravelsAtConstantSpeedAndClampsToEndpoints() {
        let route = GraphConnection(points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 30)])
        #expect(route.point(at: -1) == CGPoint(x: 0, y: 0))
        #expect(route.point(at: 0.25) == CGPoint(x: 10, y: 0))
        #expect(route.point(at: 0.5) == CGPoint(x: 10, y: 10))
        #expect(route.point(at: 0.75) == CGPoint(x: 10, y: 20))
        #expect(route.point(at: 2) == CGPoint(x: 10, y: 30))
        #expect(TeamGraphLayout(count: -1, viewport: .zero).nodes.isEmpty)
    }
}
