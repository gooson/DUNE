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
        XCTAssertTrue(app.waitAndTap(AXID.dashboardToolbarWhatsNew), "What's New toolbar button should exist on Today")

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "What's New screen should open from the Today toolbar")
    }

    func testNavigateToSettings() throws {
        navigateToSettings()
        let title = app.navigationBars["Settings"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Settings navigation title should appear")
    }

    func testNavigateToNotificationHub() throws {
        navigateToDashboard()
        XCTAssertTrue(app.waitAndTap(AXID.dashboardToolbarNotifications), "Notifications toolbar button should exist")

        let title = app.navigationBars["Notifications"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Notifications navigation title should appear")

        let readAllButton = app.descendants(matching: .any)[AXID.notificationsReadAllButton].firstMatch
        XCTAssertTrue(readAllButton.waitForExistence(timeout: 5), "Read All button should exist in notification hub")

        let deleteAllButton = app.descendants(matching: .any)[AXID.notificationsDeleteAllButton].firstMatch
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 5), "Delete All button should exist in notification hub")

        let settingsButton = app.descendants(matching: .any)[AXID.notificationsOpenSettingsButton].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Notification settings button should exist in notification hub summary")
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
