import XCTest

/// Smoke tests for the Settings screen.
/// Verifies key UI elements exist and the screen renders without crashing.
@MainActor
final class SettingsSmokeTests: UITestBaseCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToSettings()
    }

    // MARK: - Elements

    func testSettingsLoads() throws {
        let navBar = app.navigationBars["Settings"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 8), "Settings navigation title should appear")
    }

    func testWorkoutDefaultsSectionExists() throws {
        // Look for the "Rest Time" label within the form
        let restTimeLabel = app.staticTexts["Rest Time"]
        XCTAssertTrue(restTimeLabel.waitForExistence(timeout: 5), "Rest Time setting should exist")
    }

    func testExerciseDefaultsLinkExists() throws {
        XCTAssertTrue(
            elementExists(AXID.settingsRowExerciseDefaults, timeout: 5),
            "Exercise Defaults navigation link should exist"
        )
    }

    func testAppearanceSectionExists() throws {
        let appearanceHeader = app.staticTexts["Appearance"]
        XCTAssertTrue(appearanceHeader.waitForExistence(timeout: 5), "Appearance section should exist")
    }

    func testDataPrivacySectionExists() throws {
        // Scroll down to find the section
        app.swipeUp()
        let iCloudLabel = app.staticTexts["iCloud Sync"]
        XCTAssertTrue(iCloudLabel.waitForExistence(timeout: 5), "iCloud Sync toggle should exist")
    }

    func testAboutSectionExists() throws {
        app.swipeUp()
        let versionLabel = app.staticTexts["Version"]
        XCTAssertTrue(versionLabel.waitForExistence(timeout: 5), "Version row should exist")
    }
}
