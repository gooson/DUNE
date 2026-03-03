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
        let addButton = app.descendants(matching: .any)[AXID.lifeToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        // Habit form sheet should appear
        let nameField = app.textFields[AXID.habitFormName]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Habit name field should appear")

        let typePicker = app.descendants(matching: .any)[AXID.habitFormType].firstMatch
        XCTAssertTrue(typePicker.waitForExistence(timeout: 3), "Habit type picker should appear")
    }

    func testHabitFormCancelDismisses() throws {
        let addButton = app.descendants(matching: .any)[AXID.lifeToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        let cancelButton = app.descendants(matching: .any)[AXID.habitFormCancel].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Habit form cancel button should exist")
        cancelButton.tap()

        // Sheet should be dismissed — add button should be visible again
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Habit form should be dismissed")
    }

    func testSaveEmptyHabitKeepsFormPresented() throws {
        let addButton = app.descendants(matching: .any)[AXID.lifeToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        let saveButton = app.descendants(matching: .any)[AXID.habitFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Habit form save button should exist")
        saveButton.tap()

        // Empty name should fail validation and keep sheet visible
        let nameField = app.textFields[AXID.habitFormName]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Habit form should remain visible on validation failure")
    }

    func testWeeklyFrequencyShowsStepper() throws {
        let addButton = app.descendants(matching: .any)[AXID.lifeToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        let frequencyPicker = app.descendants(matching: .any)[AXID.habitFormFrequency].firstMatch
        XCTAssertTrue(frequencyPicker.waitForExistence(timeout: 3), "Frequency picker should exist")
        let weeklySegment = app.descendants(matching: .any)[AXID.habitFormFrequencyWeekly].firstMatch
        XCTAssertTrue(weeklySegment.waitForExistence(timeout: 3), "Weekly segment should exist")
        weeklySegment.tap()

        let weeklyStepper = app.descendants(matching: .any)["habit-weekly-stepper"].firstMatch
        XCTAssertTrue(weeklyStepper.waitForExistence(timeout: 3), "Weekly stepper should appear when frequency is weekly")
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
            elementExists(AXID.lifeHeroProgress, timeout: 15),
            "Life hero progress card should exist when habits are seeded"
        )
    }
}
