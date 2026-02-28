import XCTest

@MainActor
final class ExerciseUITests: BaseUITestCase {

    private func navigateToActivity() {
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 5) {
            tabBar.buttons["Activity"].tap()
        }
    }

    // MARK: - Add Button

    func testAddButtonExists() throws {
        navigateToActivity()

        let addButton = app.buttons["activity-add-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should be visible on Activity tab")
    }

    // MARK: - Add Sheet

    func testAddSheetOpens() throws {
        navigateToActivity()

        let addButton = app.buttons["activity-add-button"]
        guard addButton.waitForExistence(timeout: 5) else {
            XCTFail("Add button not found")
            return
        }
        addButton.tap()

        // ExercisePickerView appears as a sheet with a Cancel button
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Cancel button should appear in exercise picker sheet")
    }

    // MARK: - Cancel Dismisses Sheet

    func testCancelDismissesSheet() throws {
        navigateToActivity()

        let addButton = app.buttons["activity-add-button"]
        guard addButton.waitForExistence(timeout: 5) else { return }
        addButton.tap()

        let cancelButton = app.buttons["Cancel"]
        guard cancelButton.waitForExistence(timeout: 3) else { return }
        cancelButton.tap()

        // Sheet should be dismissed — add button should be visible again
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
    }
}
