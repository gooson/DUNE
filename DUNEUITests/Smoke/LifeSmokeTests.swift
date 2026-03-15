@preconcurrency import XCTest

/// Smoke tests for the Life tab.
/// Verifies key UI elements exist and the screen renders without crashing.
@MainActor
final class LifeSmokeTests: UITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }

    override func setUpWithError() throws {
        try super.setUpWithError()
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
        XCTAssertTrue(app.waitAndTap(AXID.lifeToolbarAdd), "Add button should exist")

        // Habit form sheet should appear
        let nameField = app.textFields[AXID.habitFormName]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Habit name field should appear")

        XCTAssertTrue(
            app.scrollToElementInPrimaryFormIfNeeded(AXID.habitFormType, maxSwipes: 4),
            "Habit type picker should appear"
        )
    }

    func testHabitFormCancelDismisses() throws {
        let addButton = app.buttons[AXID.lifeToolbarAdd].firstMatch
        XCTAssertTrue(app.waitAndTap(AXID.lifeToolbarAdd), "Add button should exist")

        let cancelButton = app.descendants(matching: .any)[AXID.habitFormCancel].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Habit form cancel button should exist")
        XCTAssertTrue(app.dismissModalIfPresent(cancelIdentifiers: [AXID.habitFormCancel]), "Habit form should dismiss via shared helper")

        // Sheet should be dismissed — add button should be visible again
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Habit form should be dismissed")
    }

    func testSaveEmptyHabitKeepsFormPresented() throws {
        XCTAssertTrue(app.waitAndTap(AXID.lifeToolbarAdd), "Add button should exist")

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Habit name field should appear")
        XCTAssertTrue(app.waitAndTap(AXID.habitFormSave), "Habit form save button should exist")

        // Empty name should fail validation and keep sheet visible
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Habit form should remain visible on validation failure")
    }

    func testWeeklyFrequencyShowsStepper() throws {
        XCTAssertTrue(app.waitAndTap(AXID.lifeToolbarAdd), "Add button should exist")

        XCTAssertTrue(
            app.scrollToElementInPrimaryFormIfNeeded(AXID.habitFormFrequencyWeekly, maxSwipes: 5),
            "Frequency picker should exist"
        )
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
    override var initialTabSelectionArgument: String? { "life" }

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    func testHeroProgressExists() throws {
        XCTAssertTrue(
            elementExists(AXID.lifeHeroProgress, timeout: 15),
            "Life hero progress card should exist when habits are seeded"
        )
    }

    func testHabitActionsMenuOpensEditSheet() throws {
        XCTAssertTrue(
            app.openLifeHabitActions(named: "Morning Stretch", maxSwipes: 8),
            "Habit actions should open from the seeded habit row"
        )

        let editButton = app.descendants(matching: .any)[AXID.lifeHabitActionEdit].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit action should appear in the habit actions menu")
        editButton.tap()

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Edit habit sheet should appear from the actions menu")
        XCTAssertTrue(app.dismissModalIfPresent(cancelIdentifiers: [AXID.habitFormCancel]), "Edit habit sheet should dismiss via shared helper")
    }

    func testHabitActionsMenuArchivesHabit() throws {
        let archivedHabitName = "Morning Stretch"
        XCTAssertTrue(
            app.scrollToLifeHabit(named: archivedHabitName, maxSwipes: 8),
            "Seeded habit should exist before archive"
        )

        XCTAssertTrue(
            app.openLifeHabitActions(named: archivedHabitName, maxSwipes: 8),
            "Habit actions should open from the seeded habit row"
        )
        let actionsButton = app.descendants(matching: .any)[AXID.lifeHabitActions(archivedHabitName)].firstMatch

        let archiveButton = app.descendants(matching: .any)[AXID.lifeHabitActionArchive].firstMatch
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 3), "Archive action should appear in the habit actions menu")
        archiveButton.tap()
        let habitRow = app.descendants(matching: .any)[AXID.lifeHabitRow(archivedHabitName)].firstMatch
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: habitRow)
        waitForExpectations(timeout: 5)
    }
}
