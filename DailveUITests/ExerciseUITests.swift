import XCTest

@MainActor
final class ExerciseUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    private func navigateToExercise() {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 5) {
            tabBar.buttons["Activity"].tap()
        }
    }

    // MARK: - Add Button

    func testAddButtonExists() throws {
        navigateToExercise()

        let addButton = app.buttons["exercise-add-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should be visible")
    }

    // MARK: - Add Sheet

    func testAddSheetOpens() throws {
        navigateToExercise()

        let addButton = app.buttons["exercise-add-button"]
        guard addButton.waitForExistence(timeout: 5) else {
            XCTFail("Add button not found")
            return
        }
        addButton.tap()

        // Verify sheet content
        let saveButton = app.buttons["exercise-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should appear in sheet")

        let cancelButton = app.buttons["exercise-cancel-button"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should appear in sheet")

        let datePicker = app.datePickers["exercise-date-picker"]
        XCTAssertTrue(datePicker.exists, "Date picker should appear in sheet")
    }

    // MARK: - Cancel Dismisses Sheet

    func testCancelDismissesSheet() throws {
        navigateToExercise()

        let addButton = app.buttons["exercise-add-button"]
        guard addButton.waitForExistence(timeout: 5) else { return }
        addButton.tap()

        let cancelButton = app.buttons["exercise-cancel-button"]
        guard cancelButton.waitForExistence(timeout: 3) else { return }
        cancelButton.tap()

        // Sheet should be dismissed — add button should be visible again
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
    }
}
