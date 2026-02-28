import XCTest

@MainActor
final class BodyCompositionUITests: BaseUITestCase {

    private func navigateToWellness() {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 5) {
            tabBar.buttons["Wellness"].tap()
        }
    }

    private func openBodyAddSheet() {
        navigateToWellness()
        let addMenu = app.buttons["Add record"]
        guard addMenu.waitForExistence(timeout: 5) else { return }
        addMenu.tap()

        let bodyRecordButton = app.buttons["Body Record"]
        guard bodyRecordButton.waitForExistence(timeout: 3) else { return }
        bodyRecordButton.tap()
    }

    // MARK: - Add Button

    func testAddButtonExists() throws {
        navigateToWellness()

        let addMenu = app.buttons["Add record"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Add record menu should be visible in Wellness toolbar")
    }

    // MARK: - Add Sheet

    func testAddSheetOpens() throws {
        openBodyAddSheet()

        let saveButton = app.buttons["body-save-button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should appear in sheet")

        let cancelButton = app.buttons["body-cancel-button"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should appear in sheet")

        let datePicker = app.datePickers["body-date-picker"]
        XCTAssertTrue(datePicker.exists, "Date picker should appear in sheet")
    }

    // MARK: - Form Fields

    func testFormFieldsExist() throws {
        openBodyAddSheet()

        let weightField = app.textFields["body-weight-field"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 3), "Weight field should exist")

        let fatField = app.textFields["body-fat-field"]
        XCTAssertTrue(fatField.exists, "Body fat field should exist")

        let muscleField = app.textFields["body-muscle-field"]
        XCTAssertTrue(muscleField.exists, "Muscle mass field should exist")
    }

    // MARK: - Save Button State

    func testSaveButtonDisabledWhenEmpty() throws {
        openBodyAddSheet()

        let saveButton = app.buttons["body-save-button"]
        guard saveButton.waitForExistence(timeout: 3) else { return }

        // Save should be disabled when all fields are empty
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when all fields are empty")
    }

    // MARK: - Cancel Dismisses Sheet

    func testCancelDismissesSheet() throws {
        openBodyAddSheet()

        let cancelButton = app.buttons["body-cancel-button"]
        guard cancelButton.waitForExistence(timeout: 3) else { return }
        cancelButton.tap()

        // Sheet should be dismissed — add menu button should be visible again
        let addMenu = app.buttons["Add record"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 3))
    }
}
