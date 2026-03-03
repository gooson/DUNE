import XCTest

/// Smoke tests for the Today (Dashboard) tab.
/// Verifies key UI elements exist and the screen renders without crashing.
@MainActor
final class DashboardSmokeTests: UITestBaseCase {
    // MARK: - Launch

    func testAppLaunchesOnDashboard() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
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

    func testNavigateToSettings() throws {
        navigateToSettings()
        let title = app.navigationBars["Settings"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Settings navigation title should appear")
    }

    func testNavigateToNotificationHub() throws {
        navigateToDashboard()
        let notificationsButton = app.descendants(matching: .any)[AXID.dashboardToolbarNotifications].firstMatch
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 5), "Notifications toolbar button should exist")
        notificationsButton.tap()

        let title = app.navigationBars["Notifications"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Notifications navigation title should appear")

        let readAllButton = app.buttons["Read All"].firstMatch
        XCTAssertTrue(readAllButton.waitForExistence(timeout: 5), "Read All button should exist in notification hub")
    }

    // MARK: - Tab Navigation Round-Trip

    func testTabNavigationRoundTrip() throws {
        let tabBar = app.tabBars.firstMatch

        for tab in ["Activity", "Wellness", "Life", "Today"] {
            tabBar.buttons[tab].tap()
            // Just verify no crash — existence check on tab is implicit
        }

        // Back on Today tab
        XCTAssertTrue(tabBar.buttons["Today"].isSelected)
    }
}
