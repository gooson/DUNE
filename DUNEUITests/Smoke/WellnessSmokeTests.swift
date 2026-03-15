@preconcurrency import XCTest

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
            wellnessAddMenu().waitForExistence(timeout: 5),
            "Wellness add menu button should exist in toolbar"
        )
    }

    // MARK: - Body Composition Form

    func testBodyFormOpens() throws {
        let addMenu = wellnessAddMenu()
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
        let addMenu = wellnessAddMenu()
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Add menu should exist")
        addMenu.tap()

        let bodyRecordButton = app.descendants(matching: .any)[AXID.wellnessMenuBodyRecord].firstMatch
        XCTAssertTrue(bodyRecordButton.waitForExistence(timeout: 3), "Body Record action should exist")
        bodyRecordButton.tap()

        let cancelButton = app.descendants(matching: .any)[AXID.bodyFormCancel].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "Body form cancel button should exist")
        XCTAssertTrue(app.dismissModalIfPresent(cancelIdentifiers: [AXID.bodyFormCancel]), "Body form should dismiss via shared helper")

        // Sheet should be dismissed — add menu should be visible again
        XCTAssertTrue(addMenu.waitForExistence(timeout: 3), "Body form should be dismissed")
    }

    func testBodyFormSaveEnablesAfterInput() throws {
        let addMenu = wellnessAddMenu()
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Add menu should exist")
        addMenu.tap()

        let bodyRecordButton = app.descendants(matching: .any)[AXID.wellnessMenuBodyRecord].firstMatch
        XCTAssertTrue(bodyRecordButton.waitForExistence(timeout: 3), "Body Record action should exist")
        bodyRecordButton.tap()

        let saveButton = app.descendants(matching: .any)[AXID.bodyFormSave].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Body form save button should appear")

        saveButton.tap()
        let bodyForm = app.descendants(matching: .any)[AXID.bodyFormScreen].firstMatch
        XCTAssertTrue(bodyForm.waitForExistence(timeout: 2), "Body form should remain visible without a measurement")

        XCTAssertTrue(app.fillTextInput(AXID.bodyFormWeight, with: "72.5"), "Weight field should accept shared helper input")

        saveButton.tap()
        let dismissed = NSPredicate(format: "exists == false")
        expectation(for: dismissed, evaluatedWith: bodyForm)
        waitForExpectations(timeout: 10)
    }

    // MARK: - Injury Form

    func testInjuryFormOpens() throws {
        let addMenu = wellnessAddMenu()
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
        let addMenu = wellnessAddMenu()
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Add menu should exist")
        addMenu.tap()

        let injuryButton = app.descendants(matching: .any)[AXID.wellnessMenuInjury].firstMatch
        XCTAssertTrue(injuryButton.waitForExistence(timeout: 3), "Injury action should exist")
        injuryButton.tap()

        let recoveredToggle = app.descendants(matching: .any)[AXID.injuryFormRecoveredToggle].firstMatch
        XCTAssertTrue(recoveredToggle.waitForExistence(timeout: 3), "Recovered toggle should exist")
        XCTAssertTrue(
            app.setSwitch(AXID.injuryFormRecoveredToggle, to: true, fallbackLabel: "Recovered"),
            "Recovered toggle should turn on"
        )

        XCTAssertTrue(
            app.scrollToInjuryEndDateIfNeeded(maxSwipes: 4, timeoutPerCheck: 1.5),
            "End date picker should appear after enabling recovered toggle"
        )
    }

    private func wellnessAddMenu() -> XCUIElement {
        let addMenuByIdentifier = app.descendants(matching: .any)[AXID.wellnessToolbarAdd].firstMatch
        if addMenuByIdentifier.exists {
            return addMenuByIdentifier
        }

        let addMenuByLabel = app.buttons["Add record"].firstMatch
        if addMenuByLabel.exists {
            return addMenuByLabel
        }

        return addMenuByIdentifier
    }
}
