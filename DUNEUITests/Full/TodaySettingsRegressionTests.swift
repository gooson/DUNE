@preconcurrency import XCTest

@MainActor
final class TodaySettingsRegressionTests: SeededUITestBaseCase {
    private enum Fixture {
        static let benchPressID = "barbell-bench-press"
        static let deadliftID = "conventional-deadlift"
        static let deadliftSearchQuery = "Deadlift"
        static let savedWeight = "72.5"
        static let savedReps = "8"
    }

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
        dismissMorningBriefingIfNeeded()

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
        dismissMorningBriefingIfNeeded()

        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Condition hero should exist")
        XCTAssertTrue(waitForHittable(hero, timeout: 5), "Condition hero should be tappable")
        hero.tap()

        let detail = app.descendants(matching: .any)[AXID.conditionScoreDetailScreen].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Condition score detail should open from Today hero")
    }

    func testSleepMetricOpensMetricDetailAndAllData() throws {
        dismissMorningBriefingIfNeeded()

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
        dismissMorningBriefingIfNeeded()

        let weatherCard = app.descendants(matching: .any)[AXID.dashboardWeatherCard].firstMatch
        XCTAssertTrue(weatherCard.waitForExistence(timeout: 10), "Seeded Today state should render weather card")
        weatherCard.tap()

        let weatherDetail = app.descendants(matching: .any)[AXID.weatherDetailScreen].firstMatch
        XCTAssertTrue(weatherDetail.waitForExistence(timeout: 5), "Weather detail should open from weather card")
    }

    func testPinnedMetricsEditorOpensAndDismisses() throws {
        dismissMorningBriefingIfNeeded()

        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.dashboardPinnedEdit, maxSwipes: 8),
            "Pinned edit button should be reachable"
        )

        let editButton = app.descendants(matching: .any)[AXID.dashboardPinnedEdit].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Pinned edit button should exist")
        XCTAssertTrue(waitForHittable(editButton, timeout: 5), "Pinned edit button should be tappable")
        editButton.tap()

        let editor = app.descendants(matching: .any)[AXID.pinnedMetricsEditorScreen].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Pinned metrics editor should open")

        let cancel = app.descendants(matching: .any)[AXID.pinnedMetricsEditorCancel].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Pinned metrics editor cancel button should exist")
        cancel.tap()

        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Editor should dismiss back to Today dashboard")
    }

    func testNotificationHubControlsTransitionToEmptyState() throws {
        openNotificationHub()

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
        openSettings()

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

    func testExerciseDefaultsListSearchesAndOpensEditRoute() throws {
        openExerciseDefaults()

        let row = exerciseDefaultsBenchPressRow()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Bench Press row should exist in Exercise Defaults")
        row.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseDefaultEditScreen].firstMatch.waitForExistence(timeout: 8),
            "Exercise default edit screen should open from the list row"
        )
    }

    func testExerciseDefaultEditClearsSavedValues() throws {
        openExerciseDefaults()

        let row = exerciseDefaultsBenchPressRow()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Bench Press row should exist before editing")
        row.tap()

        let editScreen = app.descendants(matching: .any)[AXID.exerciseDefaultEditScreen].firstMatch
        XCTAssertTrue(editScreen.waitForExistence(timeout: 8), "Exercise default edit screen should open")
        XCTAssertTrue(app.fillTextInput(AXID.exerciseDefaultEditWeight, with: Fixture.savedWeight), "Weight field should accept edited value")
        XCTAssertTrue(app.fillTextInput(AXID.exerciseDefaultEditReps, with: Fixture.savedReps), "Reps field should accept edited value")

        let clearButton = app.buttons[AXID.exerciseDefaultEditClear].firstMatch
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5), "Clear Exercise Settings button should exist for a saved default")
        clearButton.tap()

        let confirmClear = app.sheets.buttons["Clear Exercise Settings"].firstMatch
        XCTAssertTrue(confirmClear.waitForExistence(timeout: 5), "Clear Exercise Settings confirmation should appear")
        confirmClear.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseDefaultsScreen].firstMatch.waitForExistence(timeout: 8),
            "Clearing exercise defaults should return to the list"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseDefaultsConfiguredSection].firstMatch.waitForNonExistence(timeout: 8),
            "Configured section should disappear after clearing the only saved default"
        )
    }

    func testPreferredExercisesSearchShowsToggle() throws {
        openPreferredExercises()

        searchPreferredExercises(Fixture.deadliftSearchQuery)
        _ = app.dismissKeyboardIfPresent(timeout: 2)

        let toggle = app.switches[AXID.preferredExerciseToggle(Fixture.deadliftID)].firstMatch
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 8),
            "Deadlift preferred toggle should exist in filtered preferred exercises results"
        )
        XCTAssertTrue(waitForHittable(toggle, timeout: 5), "Deadlift preferred toggle should be hittable")
    }

    private func openNotificationHub() {
        dismissMorningBriefingIfNeeded(timeout: 1.5)

        let notificationsButton = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 5), "Notifications toolbar button should exist")
        XCTAssertTrue(waitForHittable(notificationsButton, timeout: 5), "Notifications button should be tappable")
        notificationsButton.tap()

        let hub = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(hub.waitForExistence(timeout: 8), "Notification hub should open")
    }

    private func openSettings() {
        dismissMorningBriefingIfNeeded(timeout: 1.5)

        let settingsButton = app.descendants(matching: .any)[AXID.dashboardToolbarSettings].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings toolbar button should exist")
        XCTAssertTrue(waitForHittable(settingsButton, timeout: 5), "Settings toolbar button should be tappable")
        settingsButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowRestTime].firstMatch.waitForExistence(timeout: 8),
            "Settings root should open from Today toolbar"
        )
    }

    private func openExerciseDefaults() {
        openSettings()
        let row = app.descendants(matching: .any)[AXID.settingsRowExerciseDefaults].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Exercise Defaults row should exist in Settings")
        row.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseDefaultsScreen].firstMatch.waitForExistence(timeout: 8),
            "Exercise Defaults screen should open from Settings"
        )
    }

    private func openPreferredExercises() {
        openSettings()
        let row = app.descendants(matching: .any)[AXID.settingsRowPreferredExercises].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Preferred Exercises row should exist in Settings")
        row.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.preferredExercisesScreen].firstMatch.waitForExistence(timeout: 8),
            "Preferred Exercises screen should open from Settings"
        )
    }

    private func searchPreferredExercises(_ query: String) {
        let list = app.collectionViews[AXID.preferredExercisesScreen].firstMatch.exists
            ? app.collectionViews[AXID.preferredExercisesScreen].firstMatch
            : app.collectionViews.firstMatch

        var searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: 2), list.exists {
            list.swipeDown()
            searchField = app.searchFields.firstMatch
        }

        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Preferred Exercises search field should exist")
        searchField.tap()
        searchField.typeText(query)
        _ = app.dismissKeyboardIfPresent()
    }

    private func exerciseDefaultsBenchPressRow() -> XCUIElement {
        let identifiedRow = app.descendants(matching: .any)[AXID.exerciseDefaultsRow(Fixture.benchPressID)].firstMatch
        let button = app.buttons["Bench Press"].firstMatch
        let text = app.staticTexts["Bench Press"].firstMatch
        let container = app.collectionViews[AXID.exerciseDefaultsScreen].firstMatch.exists
            ? app.collectionViews[AXID.exerciseDefaultsScreen].firstMatch
            : app.collectionViews.firstMatch

        for _ in 0..<8 {
            if identifiedRow.exists {
                return identifiedRow
            }
            if button.exists {
                return button
            }
            if text.exists {
                return text
            }
            if container.exists {
                container.swipeUp()
            }
        }

        if identifiedRow.exists {
            return identifiedRow
        }
        if button.exists {
            return button
        }
        return text
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func dismissMorningBriefingIfNeeded(timeout: TimeInterval = 5) {
        let briefingScreen = app.descendants(matching: .any)[AXID.dashboardMorningBriefingScreen].firstMatch
        let dismissButton = app.descendants(matching: .any)[AXID.dashboardMorningBriefingDismiss].firstMatch
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if dismissButton.waitForExistence(timeout: 0.25) {
                dismissButton.tap()

                let predicate = NSPredicate(format: "exists == false")
                let expectation = XCTNSPredicateExpectation(predicate: predicate, object: briefingScreen)
                XCTAssertEqual(
                    XCTWaiter.wait(for: [expectation], timeout: 5),
                    .completed,
                    "Morning Briefing should dismiss before opening Today settings regression routes"
                )
                return
            }

            if !briefingScreen.exists {
                return
            }

            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        guard !briefingScreen.exists else {
            XCTFail("Morning Briefing remained visible without exposing a dismiss button")
            return
        }
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
