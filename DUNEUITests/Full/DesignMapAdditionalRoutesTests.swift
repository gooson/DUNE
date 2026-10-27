@preconcurrency import XCTest

@MainActor
final class DesignMapAdditionalRoutesTests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
         "--ui-design-map-sleep-prediction"]
    }

    func testHealthDataQAOpensFromToday() throws {
        navigateToDashboard()
        let briefingDismiss = app.descendants(matching: .any)[AXID.dashboardMorningBriefingDismiss].firstMatch
        if briefingDismiss.exists {
            briefingDismiss.auditTap()
        }

        let cardID = "dashboard-health-qa-card"
        XCTAssertTrue(app.scrollToElementIfNeeded(cardID, maxSwipes: 18), "Health Q&A card should be reachable")
        let card = app.descendants(matching: .any)[cardID].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.auditTap()

        let send = app.buttons["health-qa-send"].firstMatch
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Health Q&A inspector should open")
        VisualAudit.capture("Health Q&A inspector")
    }

    func testSleepPredictionOpensFromWellness() throws {
        navigateToWellness()
        let sectionID = "wellness-sleep-prediction-card"
        XCTAssertTrue(app.scrollToElementIfNeeded(sectionID), "Sleep prediction card should be reachable")
        let section = app.descendants(matching: .any)[sectionID].firstMatch
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        let link = app.buttons["wellness-sleep-prediction-detail-link"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Sleep prediction should be tappable")
        link.auditTap()

        let detail = app.descendants(matching: .any)["wellness-sleep-prediction-detail-screen"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Sleep prediction detail should open")
        VisualAudit.capture("Sleep prediction detail")
    }
}

@MainActor
final class DesignMapNotificationDetailTests: SeededUITestBaseCase {
    override var uiScenario: LaunchScenario? { .notificationRoutingSeeded }

    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--ui-design-map-notification-details"]
    }

    func testNotificationMessageDetail() throws {
        openNotificationDetail(title: "Message Route Fixture",
                               screen: "notification-message-detail-screen")
    }

    func testNotificationDestinationUnavailable() throws {
        openNotificationDetail(title: "Unavailable Route Fixture",
                               screen: "notification-destination-unavailable-screen")
    }

    func testNotificationPersonalRecordsPush() throws {
        openNotificationDetail(title: "Personal Records Route Fixture",
                               screen: "activity-personal-records-detail-screen")
    }

    private func openNotificationDetail(title: String, screen: String) {
        navigateToDashboard()
        let briefingDismiss = app.buttons[AXID.dashboardMorningBriefingDismiss].firstMatch
        if briefingDismiss.exists { briefingDismiss.auditTap() }
        let notifications = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notifications.waitForExistence(timeout: 10))
        notifications.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
            .waitForExistence(timeout: 8))
        let row = app.staticTexts[title].firstMatch
        let list = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        for _ in 0..<16 where !row.exists { list.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 3), "Notification row should exist: \(title)")
        row.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[screen].firstMatch.waitForExistence(timeout: 8))
        VisualAudit.capture(title)
    }
}
