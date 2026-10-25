@preconcurrency import XCTest

@MainActor
final class TodaySettingsRegressionTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "today" }

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

    func testManualScrollToTopSettlesWithoutMovingConditionHero() throws {
        dismissMorningBriefingIfNeeded()

        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        let scrollView = app.scrollViews["dashboard-root-scroll"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Seeded Today should show the condition hero")
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8), "Today root scroll view should exist")
        XCTAssertTrue(waitForHittable(hero, timeout: 5), "The hero should start in the viewport")

        let initialHeroY = hero.frame.minY
        let positionTolerance: CGFloat = 12
        let refreshTrigger = app.buttons[AXID.waveRefreshTestTrigger].firstMatch
        XCTAssertTrue(refreshTrigger.waitForExistence(timeout: 5))
        let initialRefreshCount = try XCTUnwrap(Int(refreshTrigger.value as? String ?? ""))
        addScreenshotAttachment(named: "Today manual return initial")

        for _ in 0..<8 where hero.frame.intersects(scrollView.frame) {
            scrollView.swipeUp()
        }
        XCTAssertFalse(hero.frame.intersects(scrollView.frame), "Scroll far enough to move the hero off-screen")

        // Move the content down in bounded steps. The final step uses only the
        // remaining distance so this gesture does not cross the refresh threshold.
        for _ in 0..<12 {
            let remaining = initialHeroY - hero.frame.minY
            if hero.frame.intersects(scrollView.frame) && abs(remaining) <= positionTolerance { break }
            guard remaining > 0 else { break }

            let distance = min(remaining, min(scrollView.frame.height * 0.35, 180))
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            start.press(
                forDuration: 0.05,
                thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                withVelocity: XCUIGestureVelocity(rawValue: 100),
                thenHoldForDuration: 0.5
            )
        }
        let settledAtTop = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                hero.exists && abs(hero.frame.minY - initialHeroY) <= positionTolerance && hero.isHittable
            },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [settledAtTop], timeout: 5), .completed,
                       "Manual scrolling should return the hero to its original top position")
        addScreenshotAttachment(named: "Today manual return settled")

        for _ in 0..<3 {
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            start.press(
                forDuration: 0.05,
                thenDragTo: start.withOffset(CGVector(dx: 0, dy: 24)),
                withVelocity: XCUIGestureVelocity(rawValue: 100),
                thenHoldForDuration: 0.5
            )
            let stableHero = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in
                    hero.exists && abs(hero.frame.minY - initialHeroY) <= positionTolerance && hero.isHittable
                },
                object: nil
            )
            XCTAssertEqual(XCTWaiter.wait(for: [stableHero], timeout: 5), .completed,
                           "Repeated short pulls at the top should not shift or lock the hero")
        }
        XCTAssertEqual(try XCTUnwrap(Int(refreshTrigger.value as? String ?? "")), initialRefreshCount,
                       "Manual top return and short pulls must not trigger native refresh")

        hero.auditTap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.conditionScoreDetailScreen].firstMatch.waitForExistence(timeout: 5),
            "The condition hero should remain interactive after repeated top pulls"
        )
    }

    func testRepeatedFullSwipesAtTopSettleConditionHero() throws {
        dismissMorningBriefingIfNeeded()

        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        let scrollView = app.scrollViews["dashboard-root-scroll"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8))
        XCTAssertTrue(waitForHittable(hero, timeout: 5))
        let initialHeroY = hero.frame.minY

        for _ in 0..<6 where hero.frame.intersects(scrollView.frame) {
            scrollView.swipeUp(velocity: .slow)
        }
        XCTAssertFalse(hero.frame.intersects(scrollView.frame), "The hero should leave the viewport before returning to the top")

        for _ in 0..<12 where hero.frame.minY < initialHeroY - 12 {
            scrollView.swipeDown(velocity: .slow)
        }

        for _ in 0..<3 {
            scrollView.swipeDown(velocity: .slow)
            let settledHero = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in
                    hero.exists && abs(hero.frame.minY - initialHeroY) <= 12
                },
                object: nil
            )
            XCTAssertEqual(XCTWaiter.wait(for: [settledHero], timeout: 5), .completed,
                           "Repeated full swipes should settle the hero at its original top position")
        }

        let refreshTrigger = app.buttons[AXID.waveRefreshTestTrigger].firstMatch
        let refreshIndicator = app.descendants(matching: .any)[AXID.waveRefreshIndicator].firstMatch
        XCTAssertTrue(refreshTrigger.waitForExistence(timeout: 5))
        refreshTrigger.tap()
        XCTAssertTrue(refreshIndicator.waitForExistence(timeout: 5),
                      "The wave refresh test trigger should remain available at the top")
        let refreshFinished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: refreshIndicator
        )
        XCTAssertEqual(XCTWaiter.wait(for: [refreshFinished], timeout: 15), .completed)
        XCTAssertLessThanOrEqual(abs(hero.frame.minY - initialHeroY), 12,
                                 "The hero should remain at the top after refresh completes")
        addScreenshotAttachment(named: "Today repeated full swipes settled")
    }

    func testNativePullToRefreshKeepsTodayScrollable() throws {
        dismissMorningBriefingIfNeeded()

        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        let scrollView = app.scrollViews["dashboard-root-scroll"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8))
        XCTAssertTrue(waitForHittable(hero, timeout: 5))
        let initialHeroY = hero.frame.minY
        addScreenshotAttachment(named: "Today native pull before")

        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
        addScreenshotAttachment(named: "Today native pull after")

        XCTAssertLessThanOrEqual(abs(hero.frame.minY - initialHeroY), 12,
                                 "Today should settle at its original top after a native downward pull")
        let heroDriftsFromTop = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                hero.exists && abs(hero.frame.minY - initialHeroY) > 12
            },
            object: nil
        )
        heroDriftsFromTop.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [heroDriftsFromTop], timeout: 2), .completed,
                       "Today should remain settled after the pull finishes")

        scrollView.swipeUp(velocity: .slow)
        XCTAssertLessThan(hero.frame.minY, initialHeroY - 20,
                          "Today should respond to the next upward scroll after refresh")
    }

    func testShortUpwardScrollNearTopDoesNotSnapBack() throws {
        dismissMorningBriefingIfNeeded()

        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        let scrollView = app.scrollViews["dashboard-root-scroll"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8))
        XCTAssertTrue(waitForHittable(hero, timeout: 5))
        let initialHeroY = hero.frame.minY
        addScreenshotAttachment(named: "Today partial scroll initial")

        // Short partial drags must preserve their position. The separate full
        // swipe regression covers deceleration back toward the top.
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: -60)),
            withVelocity: XCUIGestureVelocity(rawValue: 100),
            thenHoldForDuration: 0
        )

        XCTAssertLessThan(hero.frame.minY, initialHeroY - 20,
                          "A short upward scroll must preserve the user's position instead of jumping back to the top")
        XCTAssertLessThan(initialHeroY - hero.frame.minY, 130,
                          "Exercise a small partial scroll rather than a deep swipe")
        let jumpsBackToTop = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                hero.exists && hero.frame.minY >= initialHeroY - 12
            },
            object: nil
        )
        jumpsBackToTop.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [jumpsBackToTop], timeout: 2), .completed,
                       "The scroll position must stay where the gesture left it")
        addScreenshotAttachment(named: "Today partial upward settled")

        let returnStart = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        returnStart.press(
            forDuration: 0.05,
            thenDragTo: returnStart.withOffset(CGVector(dx: 0, dy: 24)),
            withVelocity: XCUIGestureVelocity(rawValue: 100),
            thenHoldForDuration: 0
        )
        XCTAssertLessThan(hero.frame.minY, initialHeroY - 12,
                          "A partial return toward the top must also preserve its stopping position")
        let returnJumpsBackToTop = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                hero.exists && hero.frame.minY >= initialHeroY - 12
            },
            object: nil
        )
        returnJumpsBackToTop.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [returnJumpsBackToTop], timeout: 2), .completed,
                       "A partial return must not snap back to the original top position")
        addScreenshotAttachment(named: "Today partial return settled")
    }

    func testNativeRefreshReleaseWithoutHoldKeepsTodayScrollable() throws {
        dismissMorningBriefingIfNeeded()

        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        let scrollView = app.scrollViews["dashboard-root-scroll"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8))
        XCTAssertTrue(waitForHittable(hero, timeout: 5))
        let initialHeroY = hero.frame.minY
        let refreshTrigger = app.buttons[AXID.waveRefreshTestTrigger].firstMatch
        XCTAssertTrue(refreshTrigger.waitForExistence(timeout: 5))
        let initialRefreshCount = try XCTUnwrap(Int(refreshTrigger.value as? String ?? ""))

        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(
            forDuration: 0.05,
            thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)),
            withVelocity: .slow,
            thenHoldForDuration: 0
        )
        // XCTest can wait for animations until the transient indicator is gone.
        // Observe uncancelled refresh-work completion, which an immediately
        // cancelled refresh cannot report. The counter does not assert data success.
        let refreshFinished = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                (Int(refreshTrigger.value as? String ?? "") ?? initialRefreshCount) > initialRefreshCount
            }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [refreshFinished], timeout: 15), .completed)
        XCTAssertEqual(hero.frame.minY, initialHeroY, accuracy: 12,
                       "Native refresh must restore the top inset after release without a hold")
        addScreenshotAttachment(named: "Today native refresh completed without hold")

        scrollView.swipeUp(velocity: .slow)
        XCTAssertLessThan(hero.frame.minY, initialHeroY - 20,
                          "The next upward gesture must work after native refresh")
    }

    func testConditionHeroOpensConditionScoreDetail() throws {
        dismissMorningBriefingIfNeeded()

        let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Condition hero should exist")
        XCTAssertTrue(waitForHittable(hero, timeout: 5), "Condition hero should be tappable")
        hero.auditTap()

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
        sleepCard.auditTap()

        let metricDetail = app.descendants(matching: .any)[AXID.metricDetailScreen("sleep")].firstMatch
        XCTAssertTrue(metricDetail.waitForExistence(timeout: 5), "Metric detail should open from Today metric card")

        if app.windows.firstMatch.horizontalSizeClass == .regular {
            XCTAssertTrue(
                app.scrollViews["dashboard-root-scroll"].firstMatch.exists,
                "Today dashboard should remain alongside the inspector\n\(app.debugDescription)"
            )
        }
        XCTAssertTrue(
            app.waitAndTap("dashboard-metric-inspector-close"),
            "Metric inspector should provide an accessible close action\n\(app.debugDescription)"
        )
        let inspectorDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: metricDetail
        )
        XCTAssertEqual(XCTWaiter.wait(for: [inspectorDismissed], timeout: 5), .completed)
        XCTAssertTrue(
            app.scrollToHittableElementIfNeeded(AXID.dashboardMetricCard("sleep"), maxSwipes: 8),
            "Closing the inspector should leave the selected metric accessible on Today"
        )
        sleepCard.auditTap()
        XCTAssertTrue(metricDetail.waitForExistence(timeout: 5), "The same metric should reopen after inspector dismissal")

        let showAllData = app.descendants(matching: .any)[AXID.metricDetailShowAllData].firstMatch
        XCTAssertTrue(showAllData.waitForExistence(timeout: 5), "Show All Data link should exist in metric detail")
        showAllData.auditTap()

        let allData = app.descendants(matching: .any)[AXID.allDataScreen("sleep")].firstMatch
        XCTAssertTrue(allData.waitForExistence(timeout: 5), "All Data view should open from metric detail")
    }

    func testWeatherCardOpensWeatherDetail() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += ["--ui-dashboard-hour", "12", "-morningBriefingDisabled", "YES"]
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 8), "Seeded Today should load with a fixed daytime fixture")
        dismissMorningBriefingIfNeeded()

        let weatherCard = app.descendants(matching: .any)[AXID.dashboardWeatherCard].firstMatch
        XCTAssertTrue(weatherCard.waitForExistence(timeout: 10), "Seeded Today state should render weather card")
        let dashboardScroll = app.scrollViews["dashboard-root-scroll"].firstMatch
        XCTAssertTrue(dashboardScroll.waitForExistence(timeout: 5))
        func visibleWeatherViewport() -> CGRect {
            let scrollFrame = dashboardScroll.frame.intersection(app.windows.firstMatch.frame)
            let top = max(scrollFrame.minY, app.navigationBars.firstMatch.frame.maxY + 8)
            let bottom = min(scrollFrame.maxY, app.tabBars.firstMatch.frame.minY - 8)
            return CGRect(x: scrollFrame.minX, y: top, width: scrollFrame.width,
                          height: max(0, bottom - top))
        }
        for _ in 0..<24 {
            let viewport = visibleWeatherViewport()
            if weatherCard.exists && weatherCard.isHittable && viewport.contains(weatherCard.frame) { break }
            if weatherCard.exists && weatherCard.frame.midY < viewport.midY {
                dashboardScroll.swipeDown(velocity: .slow)
            } else {
                dashboardScroll.swipeUp(velocity: .slow)
            }
        }
        XCTAssertTrue(weatherCard.isHittable && visibleWeatherViewport().contains(weatherCard.frame),
                      "Weather card should be fully below the navigation bar before opening its detail")
        XCTAssertGreaterThanOrEqual(weatherCard.frame.height, 44, "Weather row should have a finger-sized tap target")
        weatherCard.auditTap()

        let weatherDetail = app.descendants(matching: .any)[AXID.weatherDetailScreen].firstMatch
        XCTAssertTrue(weatherDetail.waitForExistence(timeout: 5), "Weather detail should open from weather card")
    }

    func testPinnedMetricsEditorOpensAndDismisses() throws {
        dismissMorningBriefingIfNeeded()
        let editButton = app.descendants(matching: .any)[AXID.dashboardPinnedEdit].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Pinned edit button should exist")
        let dashboardScroll = app.scrollViews["dashboard-root-scroll"].firstMatch
        XCTAssertTrue(dashboardScroll.waitForExistence(timeout: 5))
        for _ in 0..<18 where !editButton.isHittable {
            dashboardScroll.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(waitForHittable(editButton, timeout: 5), "Pinned edit button should be tappable")
        editButton.auditTap()

        let editor = app.descendants(matching: .any)[AXID.pinnedMetricsEditorScreen].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "Pinned metrics editor should open")

        let cancel = app.descendants(matching: .any)[AXID.pinnedMetricsEditorCancel].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Pinned metrics editor cancel button should exist")
        cancel.auditTap()

        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Editor should dismiss back to Today dashboard")
    }

    func testNotificationHubControlsTransitionToEmptyState() throws {
        openNotificationHub()

        let settingsButton = app.descendants(matching: .any)[AXID.notificationsOpenSettingsButton].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Notification settings shortcut should exist")

        let readAllButton = app.descendants(matching: .any)[AXID.notificationsReadAllButton].firstMatch
        XCTAssertTrue(readAllButton.waitForExistence(timeout: 5), "Read All button should exist")
        XCTAssertTrue(readAllButton.isEnabled, "Read All should be enabled for seeded unread notifications")
        readAllButton.auditTap()

        let readAllDisabled = NSPredicate(format: "enabled == false")
        expectation(for: readAllDisabled, evaluatedWith: readAllButton)
        waitForExpectations(timeout: 5)

        let moreOptions = app.buttons[AXID.notificationsMoreOptionsButton].firstMatch
        XCTAssertTrue(moreOptions.waitForExistence(timeout: 5), "More Options should contain Delete All")
        moreOptions.auditTap()
        let deleteAllButton = app.buttons["Delete All"].firstMatch
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 5), "Delete All button should exist")
        XCTAssertTrue(deleteAllButton.isEnabled, "Delete All should stay enabled while seeded items remain")
        deleteAllButton.auditTap()

        let confirmDelete = app.sheets.buttons["Delete All"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), "Delete confirmation should appear")
        confirmDelete.auditTap()

        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.buttons["Health"].tap()
        let emptyState = app.descendants(matching: .any)[AXID.notificationsEmptyState].firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "Health filter should be empty after deleting all health items")
    }

    func testSettingsShowsPhaseTwoRows() throws {
        openSettings()
        VisualAudit.capture("Settings top controls")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("settings-row-resttime-Increment", maxSwipes: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowRestTime].firstMatch.waitForExistence(timeout: 5),
            "Rest Time row should exist"
        )
        let restStepper = app.steppers[AXID.settingsRowRestTime]
        let previousValue = restStepper.value as? String
        app.buttons["settings-row-resttime-Increment"].auditTap()
        XCTAssertNotEqual(restStepper.value as? String, previousValue, "Rest time increment must work")
        app.buttons["settings-row-resttime-Decrement"].auditTap()
        XCTAssertEqual(restStepper.value as? String, previousValue, "Rest time decrement must restore the value")
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.settingsRowExerciseDefaults, maxSwipes: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowExerciseDefaults].firstMatch.waitForExistence(timeout: 5),
            "Exercise Defaults row should exist"
        )
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.settingsRowPreferredExercises, maxSwipes: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowPreferredExercises].firstMatch.waitForExistence(timeout: 5),
            "Preferred Exercises row should exist"
        )

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.settingsRowICloudSync, maxSwipes: 32), "iCloud Sync row should be reachable")
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowICloudSync].firstMatch.waitForExistence(timeout: 5),
            "iCloud Sync row should exist"
        )

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.settingsRowLocationAccess, maxSwipes: 32), "Location Access row should be reachable")
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowLocationAccess].firstMatch.waitForExistence(timeout: 5),
            "Location Access row should exist"
        )

        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.settingsRowVersion, maxSwipes: 32), "Version row should be reachable")
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowVersion].firstMatch.waitForExistence(timeout: 5),
            "Version row should exist"
        )
        if VisualAudit.isEnabled {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.settingsRowVersion, maxSwipes: 40),
                          "The final Settings row must be reachable")
            VisualAudit.capture("Settings bottom privacy and version")
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(
                "settings-mock-status-label", maxSwipes: 20, direction: .down
            ), "Mock data status must be reachable")
            VisualAudit.capture("Settings mock status")
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(
                "settings-row-resttime-Increment", maxSwipes: 40, direction: .down
            ), "Settings top controls should be reachable")
            let scroll = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.scrollViews.firstMatch
            for index in 1...3 {
                scroll.swipeUp()
                VisualAudit.capture("Settings controls lower viewport \(index)")
            }
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(
                "settings-row-resttime-Increment", maxSwipes: 40, direction: .down
            ), "Settings should return to its top controls")
            VisualAudit.capture("Settings returned top controls")
        }

    }

    func testExerciseDefaultsListSearchesAndOpensEditRoute() throws {
        openExerciseDefaults()

        let row = exerciseDefaultsBenchPressRow()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Bench Press row should exist in Exercise Defaults")
        row.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseDefaultEditScreen].firstMatch.waitForExistence(timeout: 8),
            "Exercise default edit screen should open from the list row"
        )
    }

    func testExerciseDefaultEditClearsSavedValues() throws {
        openExerciseDefaults()

        let row = exerciseDefaultsBenchPressRow()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Bench Press row should exist before editing")
        row.auditTap()

        let editScreen = app.descendants(matching: .any)[AXID.exerciseDefaultEditScreen].firstMatch
        XCTAssertTrue(editScreen.waitForExistence(timeout: 8), "Exercise default edit screen should open")
        XCTAssertTrue(app.fillTextInput(AXID.exerciseDefaultEditWeight, with: Fixture.savedWeight), "Weight field should accept edited value")
        XCTAssertTrue(app.fillTextInput(AXID.exerciseDefaultEditReps, with: Fixture.savedReps), "Reps field should accept edited value")

        let clearButton = app.buttons[AXID.exerciseDefaultEditClear].firstMatch
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5), "Clear Exercise Settings button should exist for a saved default")
        clearButton.auditTap()

        let confirmClear = app.sheets.buttons["Clear Exercise Settings"].firstMatch
        XCTAssertTrue(confirmClear.waitForExistence(timeout: 5), "Clear Exercise Settings confirmation should appear")
        confirmClear.auditTap()

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

    func testVisualAuditCumulativeStress() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        app.terminate()
        app.launchArguments.append("--ui-visual-stress-fixture")
        app.launch()
        navigateToDashboard()
        dismissMorningBriefingIfNeeded()
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-stress-details", maxSwipes: 8),
                      "UNVERIFIED: seeded cumulative stress entry is unavailable")
        app.descendants(matching: .any)["dashboard-stress-details"].firstMatch.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)["cumulative-stress-detail-screen"].firstMatch.waitForExistence(timeout: 5),
                      "Cumulative stress detail should open")
        captureTodayAuditScroll("Today cumulative stress")
    }

    func testVisualAuditMorningBriefing() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        // Reset only this scenario's presentation gate. At night the manual
        // entry is hidden, and an earlier test may already have marked today.
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-lastBriefingDate", "1900-01-01", "-morningBriefingDisabled", "NO"
        ]
        launchApp(with: configuration)
        let briefing = app.descendants(matching: .any)[AXID.dashboardMorningBriefingScreen].firstMatch
        if !briefing.waitForExistence(timeout: 8) {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded("briefing-entry-card", maxSwipes: 8),
                          "UNVERIFIED: briefing entry unavailable at this time or with these fixtures")
            app.descendants(matching: .any)["briefing-entry-card"].firstMatch.auditTap()
        }
        XCTAssertTrue(briefing.waitForExistence(timeout: 5), "Morning briefing should open")
        captureTodayAuditScroll("Today morning briefing")
        XCTAssertTrue(app.waitAndTap(AXID.dashboardMorningBriefingDismiss), "Morning briefing should dismiss")
        VisualAudit.capture("Today after briefing dismissal")
    }

    func testVisualAuditWhatsNew() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Opt-in visual audit only") }
        dismissMorningBriefingIfNeeded()
        XCTAssertTrue(app.waitAndTapToolbarAction(AXID.dashboardToolbarNotifications),
                      "UNVERIFIED: Notification hub entry unavailable")
        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.buttons["News"].tap()
        XCTAssertTrue(app.waitAndTap(AXID.notificationsNewsRelease), "UNVERIFIED: current release unavailable")
        XCTAssertTrue(app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch.waitForExistence(timeout: 5),
                      "What's New should open")
        captureTodayAuditScroll("Today What's New")
    }

    private func captureTodayAuditScroll(_ route: String) {
        VisualAudit.capture("\(route) initial viewport")
        guard let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) else {
            XCTFail("UNVERIFIED: \(route) has no visible scroll container")
            return
        }
        for index in 1...5 {
            scroll.swipeUp()
            VisualAudit.capture("\(route) lower viewport \(index) of 5")
        }
        for _ in 0..<5 { scroll.swipeDown() }
        VisualAudit.capture("\(route) returned upper viewport")
    }

    private func openNotificationHub() {
        dismissMorningBriefingIfNeeded(timeout: 1.5)

        let notificationsButton = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 5), "Notifications toolbar button should exist")
        XCTAssertTrue(waitForHittable(notificationsButton, timeout: 5), "Notifications button should be tappable")
        notificationsButton.auditTap()

        let hub = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(hub.waitForExistence(timeout: 8), "Notification hub should open")
    }

    private func openSettings() {
        dismissMorningBriefingIfNeeded(timeout: 1.5)

        let settingsButton = app.descendants(matching: .any)[AXID.dashboardToolbarSettings].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings toolbar button should exist")
        XCTAssertTrue(waitForHittable(settingsButton, timeout: 5), "Settings toolbar button should be tappable")
        settingsButton.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.settingsRowRestTime].firstMatch.waitForExistence(timeout: 8),
            "Settings root should open from Today toolbar"
        )
    }

    private func openExerciseDefaults() {
        openSettings()
        let row = app.descendants(matching: .any)[AXID.settingsRowExerciseDefaults].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Exercise Defaults row should exist in Settings")
        row.auditTap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.exerciseDefaultsScreen].firstMatch.waitForExistence(timeout: 8),
            "Exercise Defaults screen should open from Settings"
        )
    }

    private func openPreferredExercises() {
        openSettings()
        let row = app.descendants(matching: .any)[AXID.settingsRowPreferredExercises].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Preferred Exercises row should exist in Settings")
        row.auditTap()

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
        searchField.auditTap()
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
                dismissButton.auditTap()

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
        notificationsButton.auditTap()

        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.buttons["Health"].tap()
        let emptyState = app.descendants(matching: .any)[AXID.notificationsEmptyState].firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "Health filter should show empty state without seeded notifications")
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
        VisualAudit.capture("Cloud sync consent before dismissal")

        let button = app.buttons[AXID.cloudSyncConsentLocalOnly].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Keep Local Only button should exist")
        XCTAssertTrue(button.isHittable, "Local-only consent action must remain usable")
        button.auditTap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: consentView)
        waitForExpectations(timeout: 5)
    }
}
