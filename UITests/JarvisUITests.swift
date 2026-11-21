import AppKit
import XCTest

final class JarvisUITests: XCTestCase {
    @MainActor func testViewModesSettingsAndPanelVisibilityPreserveDraft() throws {
        let app = try launch("workspace")
        choose(app, "alpha")
        click(app, "workspace.chat.alpha-two")
        expect(element(app, "companion.destination"), equals: "Release checks")
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: element(app, "companion.newChat"))
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        let draft = element(app, "companion.draft")
        XCTAssertTrue(draft.waitForExistence(timeout: 10))
        draft.click()
        draft.typeText("Synthetic unsent parity draft")
        expect(draft, key: "value", equals: "Synthetic unsent parity draft")
        click(app, "dashboard.viewMode.cards")
        expect(element(app, "dashboard.viewMode.cards"), key: "value", equals: "Selected")
        let allProjectsAction = app.buttons["All projects"]
        XCTAssertTrue(allProjectsAction.waitForExistence(timeout: 10))
        click(app, "dashboard.viewMode.graph")
        expect(element(app, "dashboard.viewMode.graph"), key: "value", equals: "Selected")
        XCTAssertTrue(allProjectsAction.waitForNonExistence(timeout: 10))
        XCTAssertTrue(element(app, "graph.node.alpha-two").waitForExistence(timeout: 10))
        click(app, "dashboard.globalSettings")
        click(app, "settings.refresh.10")
        expect(element(app, "settings.refresh.10"), key: "value", equals: "Selected")
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertTrue(element(app, "settings.refresh.10").waitForNonExistence(timeout: 10))
        click(app, "dashboard.toggleConversation")
        XCTAssertTrue(draft.waitForNonExistence(timeout: 10))
        click(app, "dashboard.toggleConversation")
        expect(draft, key: "value", equals: "Synthetic unsent parity draft")
        expect(element(app, "companion.destination"), equals: "Release checks")
        XCTAssertEqual(element(app, "verification.submissions").label, "0 submissions")
    }

    @MainActor func testPhysicalPointerLoadDoesNotInvalidateGraph() throws {
        let app = try launch("pointerLoad")
        click(app, "dashboard.toggleConversation")
        choose(app, "alpha")
        let card = element(app, "graph.node.alpha-load-0")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        click(app, "verification.startPointerLoad")
        let result = element(app, "verification.pointerLoad")
        expect(result, equals: "Recording")
        let outside = element(app, "dashboard.projectSelector")
        // Exercise AppKit hit testing and the real .onHover path, not a model-only simulation.
        for _ in 0..<12 {
            card.hover()
            outside.hover()
        }
        click(app, "verification.finishPointerLoad")
        XCTAssertTrue(result.label.hasPrefix("PASS "), result.label)
    }

    @MainActor func testHoverLoadKeepsRenderedUpdatesLocal() throws {
        let app = try launch("hoverLoad")
        click(app, "verification.startHoverLoad")
        let result = element(app, "verification.hoverLoad")
        let done = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH 'PASS ' OR label BEGINSWITH 'FAIL '"),
            object: result)
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 25), .completed)
        XCTAssertTrue(result.label.hasPrefix("PASS "), result.label)
    }
    @MainActor private func launch(_ scenario: String) throws -> XCUIApplication {
        continueAfterFailure = false
        XCTAssertTrue(
            NSRunningApplication.runningApplications(
                withBundleIdentifier: "dev.jarvis.verification"
            ).isEmpty,
            "Close the existing verification app; this run will not terminate someone else's process."
        )
        let app = XCUIApplication()
        let runID = UUID().uuidString
        app.launchArguments = ["--ui-fixture", scenario, "--ui-run-id", runID]
        app.launch()
        addTeardownBlock { @MainActor in
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Synthetic \(scenario)"
            screenshot.lifetime = .keepAlways
            self.add(screenshot)
            self.add(XCTAttachment(string: app.debugDescription))
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        }
        let marker = element(app, "verification.run")
        XCTAssertTrue(marker.waitForExistence(timeout: 15))
        XCTAssertEqual(
            marker.label, runID, "The launched artifact must own this run's synthetic state.")
        XCTAssertEqual(element(app, "verification.submissions").label, "0 submissions")
        return app
    }

    @MainActor private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor private func click(_ app: XCUIApplication, _ id: String) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: 10), "Missing \(id)")
        XCTAssertTrue(target.isEnabled, "Disabled \(id)")
        target.click()
    }

    @MainActor private func expect(
        _ target: XCUIElement, key: String = "label", equals value: String
    ) {
        let predicate = NSPredicate(format: "%K == %@", key, value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 15), .completed,
            "Expected \(key)=\(value); observed \(target.debugDescription)")
    }

    @MainActor private func choose(_ app: XCUIApplication, _ project: String) {
        click(app, "dashboard.projectSelector")
        click(app, "projectChoice.\(project)")
    }

    @MainActor func testProjectsAndChatSelection() throws {
        let app = try launch("workspace")
        click(app, "workspace.project.alpha")
        expect(element(app, "dashboard.scope"), equals: "/  Alpha Workshop")
        click(app, "workspace.chat.alpha-two")
        expect(element(app, "companion.destination"), equals: "Release checks")
        choose(app, "beta")
        expect(element(app, "dashboard.scope"), equals: "/  Beta Workshop")
        XCTAssertTrue(element(app, "workspace.chat.beta-one").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "workspace.chat.alpha-two").exists)
        expect(element(app, "companion.destination"), equals: "Planning")
        XCTAssertFalse(element(app, "companion.microphone").isEnabled)
        XCTAssertFalse(element(app, "companion.openLinkedChat").isEnabled)
    }

    @MainActor func testEmptyProject() throws {
        let app = try launch("workspace")
        choose(app, "empty")
        expect(element(app, "dashboard.empty"), equals: "No active chats in this project yet.")
        XCTAssertFalse(element(app, "companion.send").isEnabled)
    }

    @MainActor func testEmptyWorkspace() throws {
        let empty = try launch("empty")
        expect(element(empty, "dashboard.empty"), equals: "No projects available yet.")
        XCTAssertFalse(element(empty, "workspace.project.alpha").exists)
        XCTAssertFalse(element(empty, "companion.send").isEnabled)
    }

    @MainActor func testUnavailableWorkspace() throws {
        let app = try launch("unavailable")
        XCTAssertTrue(element(app, "dashboard.error").waitForExistence(timeout: 15))
        expect(element(app, "dashboard.empty"), equals: "Workspace unavailable.")
        XCTAssertFalse(element(app, "companion.send").isEnabled)
        XCTAssertEqual(element(app, "verification.submissions").label, "0 submissions")
    }

    @MainActor func testStaleSnapshotRetainsNavigation() throws {
        let app = try launch("stale")
        click(app, "workspace.project.alpha")
        XCTAssertTrue(element(app, "dashboard.error").waitForExistence(timeout: 25))
        XCTAssertTrue(element(app, "workspace.chat.alpha-two").exists)
        click(app, "workspace.chat.alpha-two")
        expect(element(app, "companion.destination"), equals: "Release checks")
        expect(element(app, "companion.activityStatus"), equals: "UNKNOWN")
    }

    @MainActor func testKeyboardNavigationAndDraftDestination() throws {
        let app = try launch("workspace")
        app.typeKey("p", modifierFlags: [.command, .shift])
        XCTAssertTrue(element(app, "projectChoice.alpha").waitForExistence(timeout: 10))
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertTrue(element(app, "projectChoice.alpha").waitForNonExistence(timeout: 10))
        click(app, "workspace.project.alpha")
        click(app, "workspace.chat.alpha-one")
        let draft = element(app, "companion.draft")
        expect(element(app, "companion.destination"), equals: "Planning")
        XCTAssertTrue(draft.waitForExistence(timeout: 10))
        draft.click()
        draft.typeText("Synthetic alpha draft")
        expect(draft, key: "value", equals: "Synthetic alpha draft")
        choose(app, "beta")
        expect(draft, key: "value", equals: "")
        XCTAssertFalse(element(app, "companion.send").isEnabled)
        XCTAssertEqual(element(app, "verification.submissions").label, "0 submissions")
        choose(app, "alpha")
        click(app, "workspace.chat.alpha-one")
        expect(draft, key: "value", equals: "Synthetic alpha draft")
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: .command)
        expect(
            element(app, "verification.submissions"), equals: "1: alpha-one | Synthetic alpha draft"
        )
        expect(draft, key: "value", equals: "")
        choose(app, "beta")
        expect(draft, key: "value", equals: "")
        XCTAssertEqual(
            element(app, "verification.submissions").label, "1: alpha-one | Synthetic alpha draft")
    }
}
