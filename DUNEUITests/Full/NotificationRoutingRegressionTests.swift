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

    func testDigestAndChecklistRowsOpenTheirFeatures() {
        openHub()
        tapNotification(title: "Daily Digest Route Fixture")
        XCTAssertTrue(app.descendants(matching: .any)["notification-daily-digest-screen"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["dashboard-daily-digest"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "84")).firstMatch.exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tapNotification(title: "Life Checklist Route Fixture")
        XCTAssertTrue(app.tabBars.buttons["Life"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Life"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["life-section-habits"].firstMatch.waitForExistence(timeout: 10))
    }

    func testReadAllKeepsNewsAvailableAndClearsCombinedBadge() {
        navigateToDashboard()
        let bell = app.buttons[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(bell.waitForExistence(timeout: 5))
        XCTAssertTrue((bell.value as? String)?.contains("unread notifications") == true,
                      "Today bell should announce the seeded combined unread count")
        openHub()
        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.buttons["News"].tap()
        XCTAssertTrue(app.buttons[AXID.notificationsNewsRelease].firstMatch.waitForExistence(timeout: 5),
                      "News filter should retain the current release")

        let readAll = app.buttons[AXID.notificationsReadAllButton].firstMatch
        XCTAssertTrue(readAll.waitForExistence(timeout: 5) && readAll.isEnabled,
                      "Seeded health items and release should make Read All available")
        readAll.tap()
        XCTAssertTrue(app.staticTexts["Inbox is all caught up"].firstMatch.waitForExistence(timeout: 5),
                      "Read All should clear the combined unread count")
        XCTAssertFalse(readAll.isEnabled, "Read All should disable after both stores are marked read")
        XCTAssertTrue(app.buttons[AXID.notificationsNewsRelease].firstMatch.exists,
                      "Marking the release read should not remove its detail route")
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertEqual(bell.value as? String, "Inbox is all caught up",
                       "Today bell should announce the cleared combined inbox after Read All")
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

    func testNotificationResponseOpensSummaryAndBackReturnsToToday() {
        let detail = app.descendants(matching: .any)["notification-daily-digest-screen"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 15), "Notification response should open today's summary")
        XCTAssertTrue(app.descendants(matching: .any)["dashboard-daily-digest"].firstMatch.waitForExistence(timeout: 15))
        let todayTab = app.tabBars.buttons["Today"].firstMatch
        if todayTab.exists {
            XCTAssertTrue(todayTab.isSelected, "Notification response should select Today")
        }

        let briefingDismiss = app.buttons[AXID.dashboardMorningBriefingDismiss].firstMatch
        let briefingClosed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: briefingDismiss)
        XCTAssertEqual(XCTWaiter.wait(for: [briefingClosed], timeout: 5), .completed)

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Summary should have a back button")
        backButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch.waitForExistence(timeout: 8))
    }
}

@MainActor
final class DeferredDigestNotificationRoutingUITests: SeededUITestBaseCase {
    override var uiScenario: LaunchScenario? { .notificationRoutingSeeded }

    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "--ui-open-notification-title", "Daily Digest Route Fixture",
            "--ui-defer-daily-digest-healthkit"
        ]
    }

    func testSummaryWaitsForHealthKitReadinessWithoutShowingEmptyState() {
        let detail = app.descendants(matching: .any)["notification-daily-digest-screen"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 15))

        let loading = app.descendants(matching: .any)["notification-daily-digest-loading"].firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 5), "Summary should wait while HealthKit access is deferred")
        XCTAssertFalse(app.staticTexts["No Health Data"].exists, "Pending authorization is not an empty result")

        XCUIDevice.shared.press(.home)
        let backgrounded = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                self.app.state == .runningBackground || self.app.state == .runningBackgroundSuspended
            }
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: backgrounded, object: nil)], timeout: 10),
            .completed,
            "Summary app should enter the background before releasing deferred HealthKit access"
        )
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let digest = app.descendants(matching: .any)["dashboard-daily-digest"].firstMatch
        XCTAssertTrue(digest.waitForExistence(timeout: 15), "Summary should load when HealthKit becomes ready")
        XCTAssertFalse(loading.exists)
    }
}

@MainActor
final class LifeChecklistResponseRoutingUITests: SeededUITestBaseCase {
    override var uiScenario: LaunchScenario? { .notificationRoutingSeeded }

    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "--ui-open-notification-title", "Life Checklist Route Fixture"
        ]
    }

    func testNotificationResponseOpensLifeChecklist() {
        let lifeTab = app.tabBars.buttons["Life"].firstMatch
        XCTAssertTrue(lifeTab.waitForExistence(timeout: 15))
        XCTAssertTrue(lifeTab.isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["life-section-habits"].firstMatch.waitForExistence(timeout: 10))
        let firstHabit = app.descendants(matching: .any)[AXID.lifeHabitRow("Morning Stretch")].firstMatch
        XCTAssertTrue(firstHabit.waitForExistence(timeout: 10))
        let visibleHabit = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: firstHabit
        )
        XCTAssertEqual(XCTWaiter.wait(for: [visibleHabit], timeout: 5), .completed)
    }
}

@MainActor
final class NotificationMetricResponseRoutingUITests: SeededUITestBaseCase {
    override var uiScenario: LaunchScenario? { .notificationRoutingSeeded }

    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "--ui-open-notification-title", "Sleep Debt Alert"
        ]
    }

    func testRouteLessNotificationOpensMetricDetail() {
        let detail = app.descendants(matching: .any)[AXID.metricDetailScreen("sleep")].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 15), "Route-less alert should open its sleep metric detail")

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        let hub = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(hub.waitForExistence(timeout: 8), "Back should return to the notification hub")
    }
}
