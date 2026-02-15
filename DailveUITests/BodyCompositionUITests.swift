import XCTest

@MainActor
final class BodyCompositionUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    private func navigateToBody() {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 5) {
            tabBar.buttons["Body"].tap()
        }
    }

    // MARK: - Add Button

    func testAddButtonExists() throws {
        navigateToBody()

        let addButton = app.buttons["body-add-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should be visible")
    }

    // MARK: - Add Sheet

    func testAddSheetOpens() throws {
        navigateToBody()

        let addButton = app.buttons["body-add-button"]
        guard addButton.waitForExistence(timeout: 5) else {
            XCTFail("Add button not found")
            return
        }
        addButton.tap()

        // Verify sheet content
        let saveButton = app.buttons["body-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should appear in sheet")

        let cancelButton = app.buttons["body-cancel-button"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should appear in sheet")

        let datePicker = app.datePickers["body-date-picker"]
        XCTAssertTrue(datePicker.exists, "Date picker should appear in sheet")
    }

    // MARK: - Form Fields

    func testFormFieldsExist() throws {
        navigateToBody()

        let addButton = app.buttons["body-add-button"]
        guard addButton.waitForExistence(timeout: 5) else { return }
        addButton.tap()

        let weightField = app.textFields["body-weight-field"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 3), "Weight field should exist")

        let fatField = app.textFields["body-fat-field"]
        XCTAssertTrue(fatField.exists, "Body fat field should exist")

        let muscleField = app.textFields["body-muscle-field"]
        XCTAssertTrue(muscleField.exists, "Muscle mass field should exist")
    }

    // MARK: - Save Button State

    func testSaveButtonDisabledWhenEmpty() throws {
        navigateToBody()

        let addButton = app.buttons["body-add-button"]
        guard addButton.waitForExistence(timeout: 5) else { return }
        addButton.tap()

        let saveButton = app.buttons["body-save-button"]
        guard saveButton.waitForExistence(timeout: 3) else { return }

        // Save should be disabled when all fields are empty
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when all fields are empty")
    }

    // MARK: - Cancel Dismisses Sheet

    func testCancelDismissesSheet() throws {
        navigateToBody()

        let addButton = app.buttons["body-add-button"]
        guard addButton.waitForExistence(timeout: 5) else { return }
        addButton.tap()

        let cancelButton = app.buttons["body-cancel-button"]
        guard cancelButton.waitForExistence(timeout: 3) else { return }
        cancelButton.tap()

        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
    }
}
