import XCTest

@MainActor
final class DailveUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        addSystemPermissionMonitor()
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

        let tabs = ["Today", "Activity", "Wellness"]
        for tab in tabs {
            let button = tabBar.buttons[tab]
            XCTAssertTrue(button.exists, "Tab '\(tab)' should exist")
            button.tap()
        }
    }

    func testReselectCurrentTabScrollsToTop() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            throw XCTSkip("iPad sidebar layout does not support this tab-bar regression test")
        }

        let activityTab = tabBar.buttons["Activity"]
        XCTAssertTrue(activityTab.exists, "Activity tab should exist")
        activityTab.tap()

        let topCard = app.buttons[AXID.activityReadinessCard]
        XCTAssertTrue(topCard.waitForExistence(timeout: 10), "Top activity card should exist")
        XCTAssertTrue(topCard.isHittable, "Top activity card should be visible before scroll")

        var swipeCount = 0
        while topCard.isHittable && swipeCount < 6 {
            app.swipeUp()
            swipeCount += 1
        }

        XCTAssertFalse(
            topCard.isHittable,
            "Top card should move out of viewport after swiping down the feed"
        )

        activityTab.tap() // reselect current tab

        let becameVisible = NSPredicate(format: "hittable == true")
        expectation(for: becameVisible, evaluatedWith: topCard)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(topCard.isHittable, "Reselecting current tab should scroll feed back to top")
    }
}
