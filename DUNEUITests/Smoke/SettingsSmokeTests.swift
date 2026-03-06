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
        scrollToElementIfNeeded(AXID.settingsSectionAppearance)
        XCTAssertTrue(
            elementExists(AXID.settingsSectionAppearance, timeout: 5),
            "Appearance section should exist"
        )
    }

    func testDataPrivacySectionExists() throws {
        scrollToElementIfNeeded(AXID.settingsRowICloudSync)
        XCTAssertTrue(
            elementExists(AXID.settingsRowICloudSync, timeout: 5),
            "iCloud Sync row should exist"
        )
        scrollToElementIfNeeded(AXID.settingsRowLocationAccess, maxSwipes: 8)
        XCTAssertTrue(
            elementExists(AXID.settingsRowLocationAccess, timeout: 5),
            "Location Access row should exist"
        )
    }

    func testAboutSectionExists() throws {
        scrollToElementIfNeeded(AXID.settingsRowVersion)
        XCTAssertTrue(
            elementExists(AXID.settingsRowVersion, timeout: 5),
            "Version row should exist"
        )
    }

    func testWhatsNewLinkExists() throws {
        scrollToElementIfNeeded(AXID.settingsRowWhatsNew)
        XCTAssertTrue(
            elementExists(AXID.settingsRowWhatsNew, timeout: 5),
            "What's New navigation link should exist"
        )
    }

    func testNavigateToWhatsNew() throws {
        scrollToElementIfNeeded(AXID.settingsRowWhatsNew)

        let link = app.descendants(matching: .any)[AXID.settingsRowWhatsNew].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "What's New link should exist")
        link.tap()

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "What's New screen should open")
    }

    func testWhatsNewNotificationRouteReturnsToTodayFlow() throws {
        scrollToElementIfNeeded(AXID.settingsRowWhatsNew)

        let link = app.descendants(matching: .any)[AXID.settingsRowWhatsNew].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "What's New link should exist")
        link.tap()

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "What's New screen should open")

        scrollToElementIfNeeded(AXID.whatsNewOpenButton("notifications"))
        let openNotificationsButton = app.descendants(matching: .any)[AXID.whatsNewOpenButton("notifications")].firstMatch
        XCTAssertTrue(
            openNotificationsButton.waitForExistence(timeout: 5),
            "Notifications open button should exist in What's New"
        )
        openNotificationsButton.tap()

        let notificationsTitle = app.navigationBars["Notifications"]
        XCTAssertTrue(
            notificationsTitle.waitForExistence(timeout: 5),
            "Notifications destination should open after leaving Settings"
        )
    }

    private func scrollToElementIfNeeded(_ identifier: String, maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes where !elementExists(identifier, timeout: 1) {
            app.swipeUp()
        }
    }
}
