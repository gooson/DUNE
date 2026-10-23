@preconcurrency import XCTest

@MainActor
final class WatchWorkoutLiveActivityUITests: UITestBaseCase {
    // These tests inspect SpringBoard, so the app-navigation setup in the base
    // class is deliberately skipped. The base teardown still ends the app.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRunningNotificationCenterPresentation() {
        captureNotificationCenter(phase: "running", expectedStatus: "Workout")
    }

    func testPausedNotificationCenterPresentation() {
        captureNotificationCenter(phase: "paused", expectedStatus: "Paused")
    }

    private func captureNotificationCenter(phase: String, expectedStatus: String) {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--ui-watch-live-activity", phase,
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        launchApp(with: configuration)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // Pull from the left side of the status bar, away from Dynamic Island.
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.01))
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.72))
        top.press(forDuration: 0.05, thenDragTo: bottom)

        let title = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Outdoor Run"))
            .firstMatch
        let didFindTitle = title.waitForExistence(timeout: 15)
        let hierarchy = springboard.debugDescription
        attachEvidence(phase: phase, hierarchy: hierarchy)

        XCTAssertTrue(didFindTitle, "SpringBoard should display the seeded workout")
        XCTAssertTrue(hierarchy.contains("Outdoor Run"), "Workout title should appear in system UI")
        XCTAssertTrue(hierarchy.contains(expectedStatus), "Workout status should appear in system UI")
        XCTAssertTrue(hierarchy.contains("142"), "Heart rate should appear in system UI")
        XCTAssertTrue(hierarchy.contains("86"), "Active calories should appear in system UI")
    }

    private func attachEvidence(phase: String, hierarchy: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "WLA01-\(phase)-notification-center"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let hierarchyAttachment = XCTAttachment(string: hierarchy)
        hierarchyAttachment.name = "WLA01-\(phase)-springboard-hierarchy"
        hierarchyAttachment.lifetime = .keepAlways
        add(hierarchyAttachment)
    }
}
