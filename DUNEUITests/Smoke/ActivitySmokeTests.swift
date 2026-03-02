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
        let navBar = app.navigationBars["Activity"].firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 15), "Activity navigation title should appear")
    }

    func testToolbarAddButtonExists() throws {
        XCTAssertTrue(
            elementExists(AXID.activityToolbarAdd, timeout: 5),
            "Activity add button should exist in toolbar"
        )
    }

    func testHeroReadinessCardExists() throws {
        XCTAssertTrue(
            elementExists(AXID.activityHeroReadiness, timeout: 8),
            "Training readiness hero card should exist"
        )
    }

    // MARK: - Exercise Sub-View

    func testExercisePickerOpens() throws {
        let addButton = app.descendants(matching: .any)[AXID.activityToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        let pickerList = app.descendants(matching: .any)[AXID.pickerRootList].firstMatch
        XCTAssertTrue(pickerList.waitForExistence(timeout: 5), "Exercise picker should appear")

        let cancel = app.buttons[AXID.pickerCancelButton]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), "Exercise picker cancel button should appear")
        cancel.tap()

        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Picker should dismiss back to Activity screen")
    }
}
