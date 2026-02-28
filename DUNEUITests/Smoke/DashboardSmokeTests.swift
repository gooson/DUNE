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

    func testNavigateToSettings() throws {
        navigateToSettings()
        let title = app.navigationBars["Settings"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Settings navigation title should appear")
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
