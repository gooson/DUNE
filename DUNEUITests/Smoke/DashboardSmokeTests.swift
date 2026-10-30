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
            "--ui-test-style", "dark",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        navigateToDashboard()
        XCTAssertTrue(app.waitAndTap(AXID.dashboardToolbarNotifications))

        let list = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "The front notification list must exist")
        let settings = app.buttons[AXID.notificationsOpenSettingsButton].firstMatch
        let readAll = app.buttons[AXID.notificationsReadAllButton].firstMatch
        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        for identifier in [AXID.notificationsOpenSettingsButton, AXID.notificationsReadAllButton, AXID.notificationsFilter] {
            let element = app.descendants(matching: .any)[identifier].firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 5))
            XCTAssertTrue(revealHubElement(element, in: list, whole: true),
                          "\(identifier) should fit and be tappable in the front list")
            XCTAssertGreaterThanOrEqual(element.frame.height, 44, "\(identifier) needs a 44-point hit target")
        }
        XCTAssertTrue(settings.exists && readAll.exists && filter.exists)
        XCTAssertFalse(settings.frame.intersects(readAll.frame), "Settings and Read All must not overlap")
        addScreenshotAttachment(named: "Notifications summary and filters maximum accessibility")

        let healthTitle = app.staticTexts["Sleep Debt Alert"].firstMatch
        let healthBody = app.staticTexts["You slept 6 h 20 m last night. Prioritize recovery today."].firstMatch
        XCTAssertTrue(healthTitle.waitForExistence(timeout: 5) && healthBody.waitForExistence(timeout: 5))
        XCTAssertTrue(revealHubElement(healthTitle, in: list, whole: true),
                      "The full health title should be readable")
        addScreenshotAttachment(named: "Notifications health title maximum accessibility dark")
        XCTAssertTrue(revealHubElement(healthBody, in: list, whole: false),
                      "The health body should have an unobscured readable portion")
        XCTAssertLessThan(healthBody.frame.minX, healthTitle.frame.minX,
                          "The health body should use the full card width below its icon-leading header")
        XCTAssertGreaterThan(healthBody.frame.height, 0, "The health body should render its full text")
        addScreenshotAttachment(named: "Notifications health row maximum accessibility dark")

        XCTAssertTrue(revealHubElement(filter, in: list, whole: true),
                      "News filter should fit before selection")
        let news = filter.buttons.element(boundBy: 2)
        XCTAssertTrue(news.waitForExistence(timeout: 5), "News is the third filter segment")
        XCTAssertTrue(revealHubElement(news, in: list, whole: true))
        XCTAssertGreaterThanOrEqual(news.frame.height, 44)
        news.tap()
        let release = app.buttons[AXID.notificationsNewsRelease].firstMatch
        let releaseTitle = app.staticTexts["What's New"].firstMatch
        let releaseIntro = app.staticTexts["notifications-news-intro"].firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: 5))
        XCTAssertTrue(releaseTitle.waitForExistence(timeout: 5) && releaseIntro.waitForExistence(timeout: 5))
        XCTAssertTrue(revealHubElement(releaseTitle, in: list, whole: true),
                      "The full release title should be readable")
        addScreenshotAttachment(named: "Notifications release title maximum accessibility dark")
        XCTAssertTrue(revealHubElement(releaseIntro, in: list, whole: false),
                      "The release intro should have an unobscured readable portion")
        XCTAssertLessThan(releaseIntro.frame.minX, releaseTitle.frame.minX,
                          "The release intro should use the full card width below its icon-leading header")
        XCTAssertFalse(releaseIntro.label.isEmpty, "The release intro should retain catalog content")
        XCTAssertGreaterThan(releaseIntro.frame.height, 0)
        addScreenshotAttachment(named: "Notifications release row maximum accessibility dark")
    }

    private func hubViewport(_ list: XCUIElement) -> CGRect {
        let frame = list.frame.intersection(app.windows.firstMatch.frame)
        let navigation = app.navigationBars.firstMatch
        let top = max(frame.minY, navigation.exists ? navigation.frame.maxY + 8 : frame.minY)
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBar.exists && tabBar.isHittable && tabBar.frame.minY > frame.midY
            ? min(frame.maxY, tabBar.frame.minY - 8) : frame.maxY
        return CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
    }

    private func revealHubElement(_ element: XCUIElement, in list: XCUIElement, whole: Bool) -> Bool {
        for _ in 0..<10 {
            let viewport = hubViewport(list)
            let frame = element.frame
            let horizontalFit = frame.minX >= viewport.minX - 2 && frame.maxX <= viewport.maxX + 2
            let verticalFit = whole ? viewport.contains(frame) : frame.intersection(viewport).height >= 24
            if horizontalFit && verticalFit && (!whole || element.isHittable) { return true }
            guard viewport.height > 100, list.frame.height > 0 else { return false }
            let movingUp = frame.midY >= viewport.midY
            let startY = movingUp ? viewport.maxY - 24 : viewport.minY + 24
            let endY = movingUp ? viewport.minY + 24 : viewport.maxY - 24
            let start = list.coordinate(withNormalizedOffset: CGVector(
                dx: 0.5, dy: (startY - list.frame.minY) / list.frame.height
            ))
            let end = list.coordinate(withNormalizedOffset: CGVector(
                dx: 0.5, dy: (endY - list.frame.minY) / list.frame.height
            ))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        return false
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
        let scroll = app.scrollViews["dashboard-root-scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        let tabBar = app.tabBars.firstMatch
        let navigationBar = app.navigationBars.firstMatch
        func visibleViewport() -> CGRect {
            let top = max(scroll.frame.minY, window.minY,
                          navigationBar.exists ? navigationBar.frame.maxY : window.minY) + 4
            let bottom = min(scroll.frame.maxY, window.maxY,
                             tabBar.exists ? tabBar.frame.minY : window.maxY) - 4
            return CGRect(x: max(scroll.frame.minX, window.minX), y: top,
                          width: min(scroll.frame.maxX, window.maxX) - max(scroll.frame.minX, window.minX),
                          height: max(0, bottom - top))
        }
        for _ in 0..<2 where !visibleViewport().contains(chart.frame) {
            let viewport = visibleViewport()
            let movement = chart.frame.maxY > viewport.maxY
                ? chart.frame.maxY - viewport.maxY + 4
                : chart.frame.minY - viewport.minY - 4
            let distance = min(abs(movement), scroll.frame.height * 0.35)
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(
                CGVector(dx: 0, dy: movement > 0 ? -distance : distance)
            ))
        }
        XCTAssertTrue(visibleViewport().contains(chart.frame),
                      "The full chart should fit between the navigation bar and tab bar")
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
