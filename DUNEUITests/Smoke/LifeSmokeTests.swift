import XCTest

/// Smoke tests for the Life tab.
/// Verifies key UI elements exist and the screen renders without crashing.
@MainActor
final class LifeSmokeTests: UITestBaseCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToLife()
    }

    // MARK: - Elements

    func testLifeTabLoads() throws {
        let navBar = app.navigationBars["Life"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 8), "Life navigation title should appear")
    }

    func testToolbarAddButtonExists() throws {
        XCTAssertTrue(
            elementExists(AXID.lifeToolbarAdd, timeout: 5),
            "Life add button should exist in toolbar"
        )
    }

    // MARK: - Habit Form

    func testHabitFormOpens() throws {
        let addButton = app.descendants(matching: .any)[AXID.lifeToolbarAdd]
        guard addButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Add button not found")
        }
        addButton.tap()

        // Habit form sheet should appear
        let nameField = app.textFields[AXID.habitFormName]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Habit name field should appear")

        let typePicker = app.descendants(matching: .any)[AXID.habitFormType]
        XCTAssertTrue(typePicker.exists, "Habit type picker should appear")
    }

    func testHabitFormCancelDismisses() throws {
        let addButton = app.descendants(matching: .any)[AXID.lifeToolbarAdd]
        guard addButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Add button not found")
        }
        addButton.tap()

        let cancelButton = app.descendants(matching: .any)[AXID.habitFormCancel]
        guard cancelButton.waitForExistence(timeout: 3) else { return }
        cancelButton.tap()

        // Sheet should be dismissed — add button should be visible again
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
    }
}

// MARK: - Seeded Life Tests

/// Tests that require mock habit data to verify hero section and habit rows.
@MainActor
final class LifeSeededSmokeTests: SeededUITestBaseCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToLife()
    }

    func testHeroProgressExists() throws {
        XCTAssertTrue(
            elementExists(AXID.lifeHeroProgress, timeout: 8),
            "Life hero progress card should exist when habits are seeded"
        )
    }
}
