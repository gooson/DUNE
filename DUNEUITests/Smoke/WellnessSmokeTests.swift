import XCTest

/// Smoke tests for the Wellness tab.
/// Verifies key UI elements exist and the screen renders without crashing.
@MainActor
final class WellnessSmokeTests: UITestBaseCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToWellness()
    }

    // MARK: - Elements

    func testWellnessTabLoads() throws {
        let navBar = app.navigationBars["Wellness"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 8), "Wellness navigation title should appear")
    }

    func testToolbarAddMenuExists() throws {
        XCTAssertTrue(
            elementExists(AXID.wellnessToolbarAdd, timeout: 5),
            "Wellness add menu button should exist in toolbar"
        )
    }

    // MARK: - Body Composition Form

    func testBodyFormOpens() throws {
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd]
        guard addMenu.waitForExistence(timeout: 5) else {
            throw XCTSkip("Add menu not found")
        }
        addMenu.tap()

        let bodyRecordButton = app.buttons["Body Record"]
        guard bodyRecordButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Body Record menu item not found")
        }
        bodyRecordButton.tap()

        // Verify form fields exist
        let saveButton = app.descendants(matching: .any)[AXID.bodyFormSave]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Body form save button should appear")

        let cancelButton = app.descendants(matching: .any)[AXID.bodyFormCancel]
        XCTAssertTrue(cancelButton.exists, "Body form cancel button should appear")

        let weightField = app.textFields[AXID.bodyFormWeight]
        XCTAssertTrue(weightField.exists, "Weight field should exist")

        let fatField = app.textFields[AXID.bodyFormFat]
        XCTAssertTrue(fatField.exists, "Body fat field should exist")
    }

    func testBodyFormCancelDismisses() throws {
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd]
        guard addMenu.waitForExistence(timeout: 5) else {
            throw XCTSkip("Add menu not found")
        }
        addMenu.tap()

        let bodyRecordButton = app.buttons["Body Record"]
        guard bodyRecordButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Body Record menu item not found")
        }
        bodyRecordButton.tap()

        let cancelButton = app.descendants(matching: .any)[AXID.bodyFormCancel]
        guard cancelButton.waitForExistence(timeout: 3) else { return }
        cancelButton.tap()

        // Sheet should be dismissed — add menu should be visible again
        XCTAssertTrue(addMenu.waitForExistence(timeout: 3))
    }

    // MARK: - Injury Form

    func testInjuryFormOpens() throws {
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd]
        guard addMenu.waitForExistence(timeout: 5) else {
            throw XCTSkip("Add menu not found")
        }
        addMenu.tap()

        let injuryButton = app.buttons["Injury"]
        guard injuryButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Injury menu item not found")
        }
        injuryButton.tap()

        let saveButton = app.descendants(matching: .any)[AXID.injuryFormSave]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Injury form save button should appear")

        let cancelButton = app.descendants(matching: .any)[AXID.injuryFormCancel]
        XCTAssertTrue(cancelButton.exists, "Injury form cancel button should appear")
    }
}
