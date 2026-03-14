@preconcurrency import XCTest

@MainActor
final class LifeRegressionTests: SeededUITestBaseCase {
    override var initialTabSelectionArgument: String? { "life" }

    override var additionalLaunchArguments: [String] {
        [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToLife()
    }

    func testLifeRootRendersAndAddFlowCreatesNewHabit() throws {
        ensureLifeRoot()
        XCTAssertTrue(waitForElement(AXID.lifeHeroProgress, timeout: 15).exists, "Life hero should exist in seeded state")
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.lifeSectionHabits, maxSwipes: 4), "Habits section should be reachable")
        XCTAssertTrue(elementExists(AXID.lifeSectionHabits, timeout: 5), "Habits section should render in seeded state")

        let addButton = app.descendants(matching: .any)[AXID.lifeToolbarAdd].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Life add button should exist")
        addButton.tap()

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Habit form should appear from the Life toolbar")
        XCTAssertTrue(app.fillTextInput(AXID.habitFormName, with: "Evening Walk"), "Habit name field should accept a new habit")

        let saveButton = app.descendants(matching: .any)[AXID.habitFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Habit save button should exist")
        saveButton.tap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: nameField)
        waitForExpectations(timeout: 5)

        XCTAssertTrue(
            app.scrollToLifeHabitActionsButton(named: "Evening Walk", maxSwipes: 8),
            "Newly saved habit should expose its actions button on the Life list"
        )
    }

    func testEditFlowRenamesSeededHabit() throws {
        openActionsMenu(for: "Morning Stretch")

        let editButton = app.descendants(matching: .any)[AXID.lifeHabitActionEdit].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit action should appear from the habit actions menu")
        editButton.tap()

        let nameField = app.textFields[AXID.habitFormName].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Edit habit form should appear")
        XCTAssertTrue(app.fillTextInput(AXID.habitFormName, with: "Morning Stretch AM"), "Edit form should allow renaming a habit")

        let saveButton = app.descendants(matching: .any)[AXID.habitFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Habit save button should exist in edit mode")
        saveButton.tap()

        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: nameField)
        waitForExpectations(timeout: 5)

        XCTAssertTrue(
            app.scrollToElementIfNeeded(AXID.lifeHabitActions("Morning Stretch AM"), maxSwipes: 6),
            "Edited habit should refresh its actions identifier after saving"
        )
    }

    func testHabitHistoryShowsSeededEntriesAndDismisses() throws {
        openHistory(for: "Morning Stretch")

        let historyScreen = app.descendants(matching: .any)[AXID.lifeHabitHistoryScreen].firstMatch
        XCTAssertTrue(historyScreen.waitForExistence(timeout: 8), "History sheet should open from the seeded habit actions menu")

        let firstRow = app.descendants(matching: .any)[AXID.lifeHabitHistoryRow(0)].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "Seeded habit history should expose at least one action row")

        XCTAssertTrue(
            app.dismissModalIfPresent(cancelIdentifiers: [AXID.lifeHabitHistoryClose]),
            "History sheet should dismiss through the shared modal helper"
        )
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: historyScreen)
        waitForExpectations(timeout: 5)
    }

    func testHabitHistoryShowsEmptyStateForHabitWithoutLogs() throws {
        openHistory(for: "Read")

        let historyScreen = app.descendants(matching: .any)[AXID.lifeHabitHistoryScreen].firstMatch
        XCTAssertTrue(historyScreen.waitForExistence(timeout: 8), "History sheet should open for a habit without logs")

        let emptyState = app.descendants(matching: .any)[AXID.lifeHabitHistoryEmpty].firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "History sheet should show an empty state when no cycle actions exist")

        XCTAssertTrue(
            app.dismissModalIfPresent(cancelIdentifiers: [AXID.lifeHabitHistoryClose]),
            "Empty history sheet should dismiss through the shared modal helper"
        )
    }

    private func ensureLifeRoot() {
        let hero = app.descendants(matching: .any)[AXID.lifeHeroProgress].firstMatch
        if hero.exists || hero.waitForExistence(timeout: 8) {
            return
        }

        navigateToLife()
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "Life hero should exist after returning to the root tab")
    }

    private func openActionsMenu(for habitName: String) {
        ensureLifeRoot()
        XCTAssertTrue(
            app.scrollToLifeHabitActionsButton(named: habitName, maxSwipes: 8),
            "\(habitName) actions button should be reachable"
        )

        let actionsButton = app.descendants(matching: .any)[AXID.lifeHabitActions(habitName)].firstMatch
        XCTAssertTrue(actionsButton.waitForExistence(timeout: 5), "\(habitName) actions button should exist")
        actionsButton.tap()
    }

    private func openHistory(for habitName: String) {
        openActionsMenu(for: habitName)

        let historyButton = app.descendants(matching: .any)[AXID.lifeHabitActionHistory].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5), "History action should appear from the habit actions menu")
        historyButton.tap()
    }
}
