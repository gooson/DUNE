@preconcurrency import XCTest

@MainActor
final class NotificationRoutingRegressionTests: SeededUITestBaseCase {
    override var uiScenario: LaunchScenario? { .notificationRoutingSeeded }

    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testBedtimeReminderPushesFromNotificationHub() {
        openHub()
        tapNotification(title: "Bedtime Route Fixture")

        XCTAssertTrue(
            app.descendants(matching: .any)["notification-sleep-detail-screen"].firstMatch.waitForExistence(timeout: 10),
            "Bedtime reminder should push sleep detail"
        )
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected, "Notification tap should keep the Today tab")
    }

    func testLegacyPostureReminderPushesAssessment() {
        openHub()
        tapNotification(title: "Posture Route Fixture")

        XCTAssertTrue(
            app.descendants(matching: .any)["posture-history-screen"].firstMatch.waitForExistence(timeout: 10),
            "Posture reminder should open posture assessment history"
        )
        XCTAssertTrue(
            app.buttons["posture-history-capture-button"].firstMatch.waitForExistence(timeout: 5),
            "Assessment should offer a capture action"
        )
    }

    func testDigestAndChecklistRowsOpenMessageDetail() {
        openHub()
        tapNotification(title: "Daily Digest Route Fixture")
        XCTAssertTrue(app.descendants(matching: .any)["notification-message-detail-screen"].firstMatch.waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tapNotification(title: "Life Checklist Route Fixture")
        XCTAssertTrue(app.descendants(matching: .any)["notification-message-detail-screen"].firstMatch.waitForExistence(timeout: 5))
    }

    private func openHub() {
        navigateToDashboard()
        let briefing = app.descendants(matching: .any)[AXID.dashboardMorningBriefingScreen].firstMatch
        if briefing.waitForExistence(timeout: 2) {
            let dismissButton = app.descendants(matching: .any)[AXID.dashboardMorningBriefingDismiss].firstMatch
            XCTAssertTrue(dismissButton.waitForExistence(timeout: 5))
            dismissButton.tap()
        }
        let notificationsButton = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 10))
        notificationsButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch.waitForExistence(timeout: 8))
    }

    private func tapNotification(title: String) {
        let rowTitle = app.staticTexts[title].firstMatch
        XCTAssertTrue(rowTitle.waitForExistence(timeout: 8), "Notification row should be present: \(title)")
        rowTitle.tap()
    }
}

@MainActor
final class NotificationResponseRoutingUITests: SeededUITestBaseCase {
    override var uiScenario: LaunchScenario? { .notificationRoutingSeeded }

    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "--ui-open-notification-title", "Daily Digest Route Fixture"
        ]
    }

    func testNotificationResponseOpensMatchingMessageAndBackReturnsToHub() {
        let detail = app.descendants(matching: .any)["notification-message-detail-screen"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 15), "Notification response should open message detail")
        XCTAssertTrue(app.staticTexts["Daily Digest Route Fixture"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Review today's summary."].firstMatch.exists)
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Message detail should have a back button")
        backButton.tap()

        let hub = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(hub.waitForExistence(timeout: 8), "Back should return to the notification hub")
        XCTAssertTrue(app.staticTexts["Daily Digest Route Fixture"].firstMatch.exists)
    }
}
