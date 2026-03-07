import XCTest

/// Smoke tests for the Activity tab.
/// Verifies key UI elements exist and the screen renders without crashing.
@MainActor
final class ActivitySmokeTests: UITestBaseCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToActivity()
    }

    // MARK: - Elements

    func testActivityTabLoads() throws {
        // Activity tab should render without crashing
        let hasNavBar = app.navigationBars.firstMatch.waitForExistence(timeout: 10)

        XCTAssertTrue(
            hasNavBar || elementExists(AXID.activityHeroReadiness, timeout: 8),
            "Activity screen should render"
        )
    }

    func testToolbarAddButtonExists() throws {
        XCTAssertTrue(
            elementExists(AXID.activityToolbarAdd, timeout: 5),
            "Activity add button should exist in toolbar"
        )
    }

    func testInlineQuickStartSearchExists() throws {
        XCTAssertTrue(
            elementExists(AXID.activityQuickStartSearch, timeout: 5),
            "Activity quick start search should exist without opening the picker"
        )
    }

    func testHeroReadinessCardExists() throws {
        XCTAssertTrue(
            elementExists(AXID.activityHeroReadiness, timeout: 8),
            "Training readiness hero card should exist"
        )
    }

    func testActivityScrollRemainsResponsive() throws {
        let readinessCard = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 15), "Readiness card should appear before scrolling")

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8), "Activity scroll view should exist")

        for _ in 0..<5 {
            scrollView.swipeUp()
        }
        for _ in 0..<5 {
            scrollView.swipeDown()
        }

        let addButton = app.descendants(matching: .any)[AXID.activityToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should still exist after scroll interactions")
    }

    func testPullToRefreshShowsWaveIndicator() throws {
        let readinessCard = app.descendants(matching: .any)[AXID.activityHeroReadiness].firstMatch
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 15), "Readiness card should appear before refresh gesture")

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 8), "Activity scroll view should exist")

        scrollView.swipeDown()

        let indicator = app.descendants(matching: .any)[AXID.waveRefreshIndicator].firstMatch
        XCTAssertTrue(indicator.waitForExistence(timeout: 3), "Wave refresh indicator should appear during pull-to-refresh")
    }

    // MARK: - Exercise Sub-View

    func testExercisePickerOpens() throws {
        let addButton = app.descendants(matching: .any)[AXID.activityToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        let pickerList = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(pickerList.waitForExistence(timeout: 5), "Exercise picker should appear")

        XCTAssertTrue(app.dismissModalIfPresent(cancelIdentifiers: [AXID.pickerCancelButton]), "Exercise picker should dismiss via shared helper")

        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Picker should dismiss back to Activity screen")
    }

    func testExercisePickerSearchAvailable() throws {
        let addButton = app.descendants(matching: .any)[AXID.activityToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        let pickerList = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(pickerList.waitForExistence(timeout: 5), "Exercise picker should appear")

        let searchField = app.descendants(matching: .any)[AXID.pickerSearchField].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Exercise picker search field should exist")

        XCTAssertTrue(app.dismissModalIfPresent(cancelIdentifiers: [AXID.pickerCancelButton]), "Exercise picker should dismiss via shared helper")
    }
}
