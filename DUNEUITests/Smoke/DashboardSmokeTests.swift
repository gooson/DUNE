@preconcurrency import XCTest

/// Smoke tests for the Today (Dashboard) tab.
/// Verifies key UI elements exist and the screen renders without crashing.
@MainActor
final class DashboardSmokeTests: UITestBaseCase {
    // MARK: - Launch

    func testAppLaunchesOnDashboard() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testDashboardNavigationBarExists() throws {
        navigateToDashboard()

        let title = app.navigationBars["Today"]
        XCTAssertTrue(title.waitForExistence(timeout: 8), "Today navigation bar should exist")
    }

    func testTabBarExists() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist on iPhone")
    }

    func testAllTabsExist() throws {
        let tabBar = app.tabBars.firstMatch
        for tab in ["Today", "Activity", "Wellness", "Life"] {
            XCTAssertTrue(tabBar.buttons[tab].exists, "Tab '\(tab)' should exist")
        }
    }

    // MARK: - Dashboard Elements

    func testSettingsButtonExists() throws {
        navigateToDashboard()
        XCTAssertTrue(
            elementExists(AXID.dashboardToolbarSettings),
            "Settings toolbar button should exist"
        )
    }

    func testNotificationButtonExists() throws {
        navigateToDashboard()
        XCTAssertTrue(
            elementExists(AXID.dashboardToolbarNotifications),
            "Notification toolbar button should exist"
        )
    }

    func testNavigateToWhatsNew() throws {
        navigateToDashboard()
        XCTAssertFalse(app.buttons["dashboard-toolbar-whatsnew"].exists,
                       "Today should use the notification hub for release news")
        XCTAssertTrue(app.waitAndTap(AXID.dashboardToolbarNotifications), "Notification hub should open from Today")

        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 5), "Notification filters should appear")
        // Picker order is All, Health, News across localizations.
        let news = filter.buttons.element(boundBy: 2)
        XCTAssertTrue(news.waitForExistence(timeout: 5))
        news.tap()

        let release = app.buttons[AXID.notificationsNewsRelease].firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: 5), "The current release should appear in News")
        addScreenshotAttachment(named: "Notifications News release")
        release.tap()

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "Release detail should open from the News filter")
        addScreenshotAttachment(named: "Notifications release detail")
    }

    func testNavigateToSettings() throws {
        navigateToSettings()
        let title = app.navigationBars["Settings"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Settings navigation title should appear")
    }

    func testNavigateToNotificationHub() throws {
        var configuration = launchConfiguration
        configuration.shouldSeedMockData = true
        configuration.scenario = .defaultSeeded
        launchApp(with: configuration)
        navigateToDashboard()
        XCTAssertTrue(app.waitAndTap(AXID.dashboardToolbarNotifications), "Notifications toolbar button should exist")

        let title = app.navigationBars["Notifications"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Notifications navigation title should appear")

        let readAllButton = app.descendants(matching: .any)[AXID.notificationsReadAllButton].firstMatch
        XCTAssertTrue(readAllButton.waitForExistence(timeout: 5), "Read All button should exist in notification hub")

        let moreOptions = app.buttons[AXID.notificationsMoreOptionsButton].firstMatch
        XCTAssertTrue(moreOptions.waitForExistence(timeout: 5), "More Options should exist in the notification hub")
        moreOptions.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@",
                                                      AXID.notificationsDeleteAllButton, ["Delete All", "전체 삭제", "すべて削除"]))
            .firstMatch.waitForExistence(timeout: 5),
                      "Delete All should appear in More Options")

        let settingsButton = app.descendants(matching: .any)[AXID.notificationsOpenSettingsButton].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Notification settings button should exist in notification hub summary")
    }

    func testNotificationHubSummaryAtMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.shouldSeedMockData = true
        configuration.scenario = .defaultSeeded
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToDashboard()
        XCTAssertTrue(app.waitAndTap(AXID.dashboardToolbarNotifications))

        let settings = app.buttons[AXID.notificationsOpenSettingsButton].firstMatch
        let readAll = app.buttons[AXID.notificationsReadAllButton].firstMatch
        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        let window = app.windows.firstMatch.frame
        for identifier in [AXID.notificationsOpenSettingsButton, AXID.notificationsReadAllButton, AXID.notificationsFilter] {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(identifier, maxSwipes: 8),
                          "\(identifier) should be reachable at maximum accessibility size")
            let element = app.descendants(matching: .any)[identifier].firstMatch
            XCTAssertTrue(window.contains(element.frame), "\(identifier) should fit inside the viewport")
        }
        XCTAssertTrue(settings.exists && readAll.exists && filter.exists)
        XCTAssertFalse(settings.frame.intersects(readAll.frame), "Settings and Read All must not overlap")
        addScreenshotAttachment(named: "Notifications summary and filters maximum accessibility")

        let news = filter.buttons.element(boundBy: 2)
        XCTAssertTrue(news.waitForExistence(timeout: 5), "News is the third filter segment")
        news.tap()
        XCTAssertTrue(app.buttons[AXID.notificationsNewsRelease].firstMatch.waitForExistence(timeout: 5))
    }

    func testConditionTrendAndHeroDetailRoute() throws {
        var configuration = launchConfiguration
        configuration.shouldSeedMockData = true
        configuration.scenario = .defaultSeeded
        configuration.additionalArguments += [
            "--ui-visual-condition-components-fixture",
            "-morningBriefingDisabled", "YES",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        launchApp(with: configuration)
        navigateToDashboard()

        XCTAssertTrue(
            app.descendants(matching: .any)["dashboard-hero-trend"].firstMatch.waitForExistence(timeout: 10),
            "Today condition trend should have a stable accessibility identifier"
        )
        let weeklyChart = app.descendants(matching: .any)["dashboard-weekly-condition-chart"].firstMatch
        XCTAssertTrue(weeklyChart.waitForExistence(timeout: 5), "Daily history should render the seven-day fallback chart")
        XCTAssertTrue(app.staticTexts["7d"].firstMatch.exists, "Fallback trend should show the seven-day period")
        XCTAssertTrue((weeklyChart.value as? String ?? "").contains("Minimum 66, maximum 100, current 100."),
                      "The chart should use the displayed score of 100, not the stale history score of 84")

        let hero = app.buttons[AXID.dashboardHeroCondition].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5), "Today hero should be one accessible detail link")
        XCTAssertFalse(app.buttons["dashboard-primary-activity"].exists,
                       "Today hero should not contain a cross-tab Activity action")
        hero.tap()

        XCTAssertTrue(elementExists(AXID.conditionScoreDetailScreen, timeout: 8),
                      "Today hero should open condition score detail")
    }

    func testTodayLogWeightOpensWellnessBodyForm() throws {
        var configuration = launchConfiguration
        configuration.shouldSeedMockData = true
        configuration.scenario = .defaultSeeded
        configuration.additionalArguments += ["-morningBriefingDisabled", "YES"]
        launchApp(with: configuration)
        navigateToDashboard()

        let logWeight = app.buttons["dashboard-quick-action-weight"].firstMatch
        XCTAssertTrue(app.scrollToElementIfNeeded("dashboard-quick-actions", maxSwipes: 12), "Today quick actions should be reachable")
        XCTAssertTrue(logWeight.waitForExistence(timeout: 5), "Log Weight quick action should appear")
        logWeight.tap()

        XCTAssertTrue(app.navigationBars["Wellness"].waitForExistence(timeout: 8), "Log Weight should open Wellness")
        XCTAssertTrue(
            app.descendants(matching: .any)[AXID.bodyFormScreen].firstMatch.waitForExistence(timeout: 8),
            "Log Weight should present the body measurement form"
        )
    }

    // MARK: - Tab Navigation Round-Trip

    func testTabNavigationRoundTrip() throws {
        for tab in ["Activity", "Wellness", "Life", "Today"] {
            app.navigateToTab(tab)
            XCTAssertTrue(
                app.navigationBars[tab].waitForExistence(timeout: 5),
                "\(tab) root navigation bar should appear after tab switch"
            )
        }
    }
}

@MainActor
final class DashboardLoadingTests: UITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-defer-daily-digest-healthkit", "-morningBriefingDisabled", "YES",
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testSkeletonUntilFirstQueryCompletes() {
        assertLoadingSkeleton()
        addScreenshotAttachment(named: "Today T03 loading skeleton")

        resumeAuthorization()

        let skeleton = app.otherElements["dashboard-loading-skeleton"].firstMatch
        let finished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: skeleton
        )
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 15), .completed)
        // Existing HealthKit measurements survive an app reset. The unit tests
        // cover deterministic empty responses; this test checks the launch lifecycle.
        if app.otherElements["dashboard-empty-state"].firstMatch.exists {
            XCTAssertTrue(app.staticTexts["No Measurements Yet"].firstMatch.exists)
        }
        addScreenshotAttachment(named: "Today T03 completed first query")
    }

    func testSkeletonTransitionsToMeasurements() {
        var configuration = launchConfiguration
        configuration.shouldSeedMockData = true
        configuration.scenario = .defaultSeeded
        launchApp(with: configuration)
        assertLoadingSkeleton()
        addScreenshotAttachment(named: "Today T03 loading before measurements")

        resumeAuthorization()

        XCTAssertTrue(app.descendants(matching: .any)["dashboard-hero-condition"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.otherElements["dashboard-loading-skeleton"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["No Measurements Yet"].firstMatch.exists)
        addScreenshotAttachment(named: "Today T03 loaded measurements")
    }

    private func assertLoadingSkeleton() {
        XCTAssertTrue(app.otherElements["dashboard-loading-skeleton"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No Measurements Yet"].firstMatch.exists)
    }

    private func resumeAuthorization() {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}

@MainActor
final class TodayDesignMapCaptureTests: UITestBaseCase {
    override var shouldSeedMockData: Bool { true }
    override var additionalLaunchArguments: [String] {
        ["-morningBriefingDisabled", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testTodayRootRenders() {
        XCTAssertTrue(app.descendants(matching: .any)["dashboard-hero-condition"].firstMatch.waitForExistence(timeout: 15))
    }

    func testRecoverySleepUsesSeededHistory() {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded("dashboard-recovery-sleep-chart", maxSwipes: 12),
                      "Seven-day sleep bars should be reachable with seeded daily sleep history")
        let chart = app.descendants(matching: .any)["dashboard-recovery-sleep-chart"].firstMatch
        XCTAssertTrue(chart.isHittable)
        let readableViewport = app.windows.firstMatch.frame.insetBy(dx: 0, dy: 140)
        for _ in 0..<4 where !readableViewport.contains(chart.frame) { app.swipeUp() }
        XCTAssertTrue(readableViewport.contains(chart.frame), "The full chart should be above the tab bar")
        XCTAssertTrue(app.descendants(matching: .any)["dashboard-recovery-sleep-card"].firstMatch.exists,
                      "The history chart should remain inside Recovery & Sleep")
        addScreenshotAttachment(named: "Today Recovery Sleep seven day chart")
    }
}

@MainActor
final class LifeDesignMapCaptureTests: UITestBaseCase {
    override var shouldSeedMockData: Bool { true }
    override var initialTabSelectionArgument: String? { "life" }

    func testLifeRootRenders() {
        XCTAssertTrue(app.descendants(matching: .any)["life-hero-progress"].firstMatch.waitForExistence(timeout: 15))
    }
}

@MainActor
final class WellnessDesignMapCaptureTests: UITestBaseCase {
    override var shouldSeedMockData: Bool { true }
    override var initialTabSelectionArgument: String? { "wellness" }

    func testWellnessRootRenders() {
        XCTAssertTrue(app.descendants(matching: .any)["wellness-hero-score"].firstMatch.waitForExistence(timeout: 15))
    }
}
