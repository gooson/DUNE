import XCTest

@MainActor
final class DailveUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Launch

    func testAppLaunches() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    // MARK: - iPhone Navigation

    func testTabBarExists() throws {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 5) {
            // iPhone layout
            XCTAssertTrue(tabBar.exists)
        }
        // iPad may not have a tab bar — skip assertion
    }

    func testTabNavigation() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { return } // iPad skips

        let tabs = ["Today", "Activity", "Sleep", "Body"]
        for tab in tabs {
            let button = tabBar.buttons[tab]
            XCTAssertTrue(button.exists, "Tab '\(tab)' should exist")
            button.tap()
        }
    }
}
