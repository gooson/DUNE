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
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Add menu should exist")
        addMenu.tap()

        let bodyRecordButton = app.descendants(matching: .any)[AXID.wellnessMenuBodyRecord].firstMatch
        XCTAssertTrue(bodyRecordButton.waitForExistence(timeout: 3), "Body Record action should exist")
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
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Add menu should exist")
        addMenu.tap()

        let bodyRecordButton = app.descendants(matching: .any)[AXID.wellnessMenuBodyRecord].firstMatch
        XCTAssertTrue(bodyRecordButton.waitForExistence(timeout: 3), "Body Record action should exist")
        bodyRecordButton.tap()

        let cancelButton = app.descendants(matching: .any)[AXID.bodyFormCancel].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Body form cancel button should exist")
        cancelButton.tap()

        // Sheet should be dismissed — add menu should be visible again
        XCTAssertTrue(addMenu.waitForExistence(timeout: 3), "Body form should be dismissed")
    }

    func testBodyFormSaveEnablesAfterInput() throws {
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Add menu should exist")
        addMenu.tap()

        let bodyRecordButton = app.descendants(matching: .any)[AXID.wellnessMenuBodyRecord].firstMatch
        XCTAssertTrue(bodyRecordButton.waitForExistence(timeout: 3), "Body Record action should exist")
        bodyRecordButton.tap()

        let saveButton = app.descendants(matching: .any)[AXID.bodyFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Body form save button should appear")
        XCTAssertFalse(saveButton.isEnabled, "Save should be disabled when all inputs are empty")

        let weightField = app.textFields[AXID.bodyFormWeight]
        XCTAssertTrue(weightField.waitForExistence(timeout: 3), "Weight field should exist")
        weightField.tap()
        weightField.typeText("72.5")

        XCTAssertTrue(saveButton.isEnabled, "Save should be enabled after weight input")
    }

    // MARK: - Injury Form

    func testInjuryFormOpens() throws {
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Add menu should exist")
        addMenu.tap()

        let injuryButton = app.descendants(matching: .any)[AXID.wellnessMenuInjury].firstMatch
        XCTAssertTrue(injuryButton.waitForExistence(timeout: 3), "Injury action should exist")
        injuryButton.tap()

        let saveButton = app.descendants(matching: .any)[AXID.injuryFormSave]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Injury form save button should appear")

        let cancelButton = app.descendants(matching: .any)[AXID.injuryFormCancel]
        XCTAssertTrue(cancelButton.exists, "Injury form cancel button should appear")
    }

    func testInjuryRecoveredToggleShowsEndDate() throws {
        let addMenu = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Add menu should exist")
        addMenu.tap()

        let injuryButton = app.descendants(matching: .any)[AXID.wellnessMenuInjury].firstMatch
        XCTAssertTrue(injuryButton.waitForExistence(timeout: 3), "Injury action should exist")
        injuryButton.tap()

        let recoveredToggle = app.switches["Recovered"].firstMatch
        XCTAssertTrue(recoveredToggle.waitForExistence(timeout: 3), "Recovered toggle should exist")
        recoveredToggle.tap()

        let endDate = app.descendants(matching: .any)[AXID.injuryFormEndDate].firstMatch
        XCTAssertTrue(endDate.waitForExistence(timeout: 3), "End date picker should appear after enabling recovered toggle")
    }
}
