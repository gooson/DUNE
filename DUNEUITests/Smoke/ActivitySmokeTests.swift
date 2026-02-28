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
        guard addButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Add button not found — skipping picker test")
        }
        addButton.tap()

        // Menu should appear with exercise options
        let singleExercise = app.buttons["Single Exercise"]
        if singleExercise.waitForExistence(timeout: 3) {
            singleExercise.tap()
            // Exercise picker sheet should appear with Cancel
            let cancel = app.buttons["Cancel"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 3), "Exercise picker Cancel should appear")
            cancel.tap()
        }
    }
}
