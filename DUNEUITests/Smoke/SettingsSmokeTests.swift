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
        XCTAssertTrue(
            elementExists(AXID.settingsRowRestTime, timeout: 5),
            "Rest Time setting row should exist"
        )
    }

    func testExerciseDefaultsLinkExists() throws {
        XCTAssertTrue(
            elementExists(AXID.settingsRowExerciseDefaults, timeout: 5),
            "Exercise Defaults navigation link should exist"
        )
    }

    func testNavigateToExerciseDefaults() throws {
        let link = app.descendants(matching: .any)[AXID.settingsRowExerciseDefaults].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Exercise Defaults link should exist")
        link.tap()

        let title = app.navigationBars["Exercise Defaults"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Exercise Defaults screen should open")
    }

    func testAppearanceSectionExists() throws {
        XCTAssertTrue(
            elementExists(AXID.settingsSectionAppearance, timeout: 5),
            "Appearance section should exist"
        )
    }

    func testDataPrivacySectionExists() throws {
        // Scroll down to find the section
        app.swipeUp()
        XCTAssertTrue(
            elementExists(AXID.settingsRowICloudSync, timeout: 5),
            "iCloud Sync row should exist"
        )
        XCTAssertTrue(
            elementExists(AXID.settingsRowLocationAccess, timeout: 5),
            "Location Access row should exist"
        )
    }

    func testAboutSectionExists() throws {
        app.swipeUp()
        XCTAssertTrue(
            elementExists(AXID.settingsRowVersion, timeout: 5),
            "Version row should exist"
        )
    }
}
