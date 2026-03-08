@preconcurrency import XCTest

@MainActor
final class TodaySettingsRegressionTests: SeededUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToDashboard()
    }

    func testTodayTabReselectScrollsConditionHeroToTop() throws {
        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Condition hero should appear for seeded Today state")

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8), "Today scroll view should exist")

        for _ in 0..<8 where hero.isHittable {
            scrollView.swipeUp()
        }

        XCTAssertFalse(hero.isHittable, "Condition hero should move off-screen before reselection")

        app.navigateToTab("Today")

        let predicate = NSPredicate(format: "hittable == true")
        expectation(for: predicate, evaluatedWith: hero)
        waitForExpectations(timeout: 5)
    }

    func testConditionHeroOpensConditionScoreDetail() throws {
        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Condition hero should exist")
        hero.tap()

        let detail = app.descendants(matching: .any)[AXID.conditionScoreDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Condition score detail should open from Today hero")
    }

    func testSleepMetricOpensMetricDetailAndAllData() throws {
        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.dashboardMetricCard("sleep")),
            "Sleep metric card should be reachable on Today"
        )

        let sleepCard = app.descendants(matching: .any)[AXID.dashboardMetricCard("sleep")].firstMatch
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 5), "Sleep metric card should exist")
        sleepCard.tap()

        let metricDetail = app.descendants(matching: .any)[AXID.metricDetailScreen("sleep")].firstMatch
        XCTAssertTrue(metricDetail.waitForExistence(timeout: 5), "Metric detail should open from Today metric card")

        let showAllData = app.descendants(matching: .any)[AXID.metricDetailShowAllData].firstMatch
        XCTAssertTrue(showAllData.waitForExistence(timeout: 5), "Show All Data link should exist in metric detail")
        showAllData.tap()

        let allData = app.descendants(matching: .any)[AXID.allDataScreen("sleep")].firstMatch
        XCTAssertTrue(allData.waitForExistence(timeout: 5), "All Data view should open from metric detail")
    }

    func testWeatherCardOpensWeatherDetail() throws {
        let weatherCard = app.descendants(matching: .any)[AXID.dashboardWeatherCard].firstMatch
        XCTAssertTrue(weatherCard.waitForExistence(timeout: 10), "Seeded Today state should render weather card")
        weatherCard.tap()

        let weatherDetail = app.descendants(matching: .any)[AXID.weatherDetailScreen].firstMatch
        XCTAssertTrue(weatherDetail.waitForExistence(timeout: 5), "Weather detail should open from weather card")
    }

    func testPinnedMetricsEditorOpensAndDismisses() throws {
        let identifiedEditButton = app.descendants(matching: .any)[AXID.dashboardPinnedEdit].firstMatch
        let labeledEditButton = app.buttons["Edit"].firstMatch
        let editButton = identifiedEditButton.waitForExistence(timeout: 2) ? identifiedEditButton : labeledEditButton
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Pinned edit button should exist")
        editButton.tap()

        let editor = app.descendants(matching: .any)[AXID.pinnedMetricsEditorScreen].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Pinned metrics editor should open")

        let cancel = app.descendants(matching: .any)[AXID.pinnedMetricsEditorCancel].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Pinned metrics editor cancel button should exist")
        cancel.tap()

        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Editor should dismiss back to Today dashboard")
    }

    func testNotificationHubControlsTransitionToEmptyState() throws {
        let notificationsButton = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 5), "Notifications toolbar button should exist")
        notificationsButton.tap()

        let navBar = app.navigationBars["Notifications"].firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Notification hub should open")

        let settingsButton = app.descendants(matching: .any)[AXID.notificationsOpenSettingsButton].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Notification settings shortcut should exist")

        let readAllButton = app.descendants(matching: .any)[AXID.notificationsReadAllButton].firstMatch
        XCTAssertTrue(readAllButton.waitForExistence(timeout: 5), "Read All button should exist")
        XCTAssertTrue(readAllButton.isEnabled, "Read All should be enabled for seeded unread notifications")
        readAllButton.tap()

        let readAllDisabled = NSPredicate(format: "enabled == false")
        expectation(for: readAllDisabled, evaluatedWith: readAllButton)
        waitForExpectations(timeout: 5)

        let deleteAllButton = app.buttons["Delete All"].firstMatch
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 5), "Delete All button should exist")
        XCTAssertTrue(deleteAllButton.isEnabled, "Delete All should stay enabled while seeded items remain")
        deleteAllButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let confirmDelete = app.sheets.buttons["Delete All"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation should appear")
        confirmDelete.tap()

        let emptyState = app.descendants(matching: .any)[AXID.notificationsEmptyState].firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "Notification hub should show empty state after deleting all items")
    }

    func testSettingsShowsPhaseTwoRows() throws {
        navigateToSettings()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowRestTime].firstMatch.waitForExistence(timeout: 5),
            "Rest Time row should exist"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowExerciseDefaults].firstMatch.waitForExistence(timeout: 5),
            "Exercise Defaults row should exist"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowPreferredExercises].firstMatch.waitForExistence(timeout: 5),
            "Preferred Exercises row should exist"
        )

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.settingsRowICloudSync), "iCloud Sync row should be reachable")
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowICloudSync].firstMatch.waitForExistence(timeout: 5),
            "iCloud Sync row should exist"
        )

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.settingsRowLocationAccess), "Location Access row should be reachable")
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowLocationAccess].firstMatch.waitForExistence(timeout: 5),
            "Location Access row should exist"
        )

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.settingsRowVersion), "Version row should be reachable")
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowVersion].firstMatch.waitForExistence(timeout: 5),
            "Version row should exist"
        )
    }
}

@MainActor
final class TodaySettingsEmptyStateRegressionTests: UITestBaseCase {
    func testNotificationHubShowsEmptyStateWithoutSeed() throws {
        navigateToDashboard()

        let notificationsButton = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 5), "Notifications toolbar button should exist")
        notificationsButton.tap()

        let emptyState = app.descendants(matching: .any)[AXID.notificationsEmptyState].firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "Notification hub should show empty state without seeded notifications")
    }
}

@MainActor
final class CloudSyncConsentRegressionTests: UITestBaseCase {
    override var additionalLaunchArguments: [String] {
        [
            "--ui-force-cloud-sync-consent",
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchApp()
    }

    func testCloudSyncConsentHookPresentsAndDismissesSheet() throws {
        let consentView = app.descendants(matching: .any)[AXID.cloudSyncConsentView].firstMatch
        XCTAssertTrue(consentView.waitForExistence(timeout: 5), "Consent hook should present cloud sync consent sheet")

        let button = app.buttons["Keep Local Only"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Keep Local Only button should exist")
        button.tap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: consentView)
        waitForExpectations(timeout: 5)
    }
}
