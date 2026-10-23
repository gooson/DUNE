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
        filter.buttons["News"].tap()

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
        XCTAssertTrue(app.buttons["Delete All"].waitForExistence(timeout: 5),
                      "Delete All should appear in More Options")

        let settingsButton = app.descendants(matching: .any)[AXID.notificationsOpenSettingsButton].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Notification settings button should exist in notification hub summary")
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
final class TodayDesignMapCaptureTests: UITestBaseCase {
    override var shouldSeedMockData: Bool { true }
    override var additionalLaunchArguments: [String] {
        ["-morningBriefingDisabled", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testTodayRootRenders() {
        XCTAssertTrue(app.descendants(matching: .any)["dashboard-hero-condition"].firstMatch.waitForExistence(timeout: 15))
    }

    func testRecoverySleepUsesSeededHistory() {
        XCTAssertTrue(app.scrollToElementIfNeeded("dashboard-recovery-sleep-chart", maxSwipes: 12),
                      "Seven-day sleep bars should be reachable with seeded daily sleep history")
        let chart = app.descendants(matching: .any)["dashboard-recovery-sleep-chart"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
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
