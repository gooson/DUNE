@preconcurrency import XCTest

@MainActor
final class WatchWorkoutLiveActivityUITests: UITestBaseCase {
    // These tests inspect SpringBoard, so the app-navigation setup in the base
    // class is deliberately skipped. The base teardown still ends the app.
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRunningNotificationCenterPresentation() {
        captureNotificationCenter(phase: "running", expectedStatuses: ["Workout", "운동", "ワークアウト"])
    }

    func testPausedNotificationCenterPresentation() {
        captureNotificationCenter(phase: "paused", expectedStatuses: ["Paused", "일시 정지", "一時停止"])
    }

    private func captureNotificationCenter(phase: String, expectedStatuses: [String]) {
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
        // Extensions use SpringBoard's language, independent of the app launch locale.
        let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "허용", "許可"])).firstMatch
        if allow.waitForExistence(timeout: 2) { allow.tap() }

        let activity = springboard.otherElements.containing(.staticText, identifier: "Outdoor Run")
            .allElementsBoundByIndex
            .filter { $0.frame.width > 250 && $0.frame.height > 70 && $0.frame.height < 220 }
            .min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        let hierarchy = springboard.debugDescription
        attachEvidence(phase: phase, hierarchy: hierarchy, activity: activity)

        XCTAssertTrue(didFindTitle, "SpringBoard should display the seeded workout")
        XCTAssertTrue(hierarchy.contains("Outdoor Run"), "Workout title should appear in system UI")
        XCTAssertTrue(expectedStatuses.contains(where: hierarchy.contains), "Localized workout status should appear in system UI")
        XCTAssertTrue(hierarchy.contains("142"), "Heart rate should appear in system UI")
        XCTAssertTrue(hierarchy.contains("86"), "Active calories should appear in system UI")
    }

    private func attachEvidence(phase: String, hierarchy: String, activity: XCUIElement?) {
        // Capture only our Live Activity; unrelated notifications may exist on the simulator.
        XCTAssertNotNil(activity, "The system should expose the workout activity container")
        if let activity {
            let screenshot = XCTAttachment(screenshot: activity.screenshot())
            screenshot.name = "WLA01-\(phase)-notification-center"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }

        let hierarchyAttachment = XCTAttachment(string: hierarchy)
        hierarchyAttachment.name = "WLA01-\(phase)-springboard-hierarchy"
        hierarchyAttachment.lifetime = .keepAlways
        add(hierarchyAttachment)
    }
}
