@preconcurrency import XCTest

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

    func testBedtimeReminderSettingsExist() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsRowBedtimeReminder)

        XCTAssertTrue(
            elementExists(AXID.settingsRowBedtimeReminder, timeout: 5),
            "General bedtime reminder row should exist"
        )
        XCTAssertTrue(
            elementExists(AXID.settingsRowBedtimeReminderLeadTime, timeout: 5),
            "General bedtime lead time row should exist"
        )
        XCTAssertTrue(
            elementExists(AXID.settingsRowAppleWatchBedtimeReminder, timeout: 5),
            "Apple Watch bedtime reminder row should exist"
        )
        XCTAssertTrue(
            elementExists(AXID.settingsRowAppleWatchBedtimeReminderLeadTime, timeout: 5),
            "Apple Watch bedtime lead time row should exist"
        )
        XCTAssertTrue(
            elementExists(AXID.settingsRowPostureReminder, timeout: 5),
            "Posture reminder row should exist"
        )

        _ = app.scrollToHittableElementIfNeeded(AXID.settingsRowPostureReminder)
        addScreenshotAttachment(named: defaultArtifactName(suffix: "bedtime-settings"))
    }

    func testExerciseDefaultsLinkExists() throws {
        XCTAssertTrue(
            elementExists(AXID.settingsRowExerciseDefaults, timeout: 5),
            "Exercise Defaults navigation link should exist"
        )
    }

    func testPreferredExercisesLinkExists() throws {
        XCTAssertTrue(
            elementExists(AXID.settingsRowPreferredExercises, timeout: 5),
            "Preferred Exercises navigation link should exist"
        )
    }

    func testNavigateToExerciseDefaults() throws {
        let link = app.descendants(matching: .any)[AXID.settingsRowExerciseDefaults].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Exercise Defaults link should exist")
        link.tap()

        let title = app.navigationBars["Exercise Defaults"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Exercise Defaults screen should open")
    }

    func testNavigateToPreferredExercises() throws {
        let link = app.descendants(matching: .any)[AXID.settingsRowPreferredExercises].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Preferred Exercises link should exist")
        link.tap()

        let title = app.navigationBars["Preferred Exercises"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Preferred Exercises screen should open")
    }

    func testAppearanceSectionExists() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsSectionAppearance)
        XCTAssertTrue(
            elementExists(AXID.settingsSectionAppearance, timeout: 5),
            "Appearance section should exist"
        )
    }

    func testDataPrivacySectionExists() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsRowICloudSync)
        XCTAssertTrue(
            elementExists(AXID.settingsRowICloudSync, timeout: 5),
            "iCloud Sync row should exist"
        )
        _ = app.scrollToElementIfNeeded(AXID.settingsRowLocationAccess, maxSwipes: 8)
        XCTAssertTrue(
            elementExists(AXID.settingsRowLocationAccess, timeout: 5),
            "Location Access row should exist"
        )
    }

    func testSimulatorMockDataControlsExist() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsButtonSeedAdvancedMockData, maxSwipes: 8)
        XCTAssertTrue(
            elementExists(AXID.settingsButtonSeedAdvancedMockData, timeout: 5),
            "Seed Advanced Mock Data button should exist on simulator"
        )
        XCTAssertTrue(
            elementExists(AXID.settingsButtonResetMockData, timeout: 5),
            "Reset Mock Data button should exist on simulator"
        )
    }

    func testAboutSectionExists() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsRowVersion)
        XCTAssertTrue(
            elementExists(AXID.settingsRowVersion, timeout: 5),
            "Version row should exist"
        )
    }

    func testWhatsNewLinkExists() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsRowWhatsNew)
        XCTAssertTrue(
            elementExists(AXID.settingsRowWhatsNew, timeout: 5),
            "What's New navigation link should exist"
        )
    }

    func testNavigateToWhatsNew() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsRowWhatsNew)

        let link = app.descendants(matching: .any)[AXID.settingsRowWhatsNew].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "What's New link should exist")
        link.tap()

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "What's New screen should open")
    }

    func testWhatsNewNotificationsDetailShowsArtwork() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsRowWhatsNew)

        let link = app.descendants(matching: .any)[AXID.settingsRowWhatsNew].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "What's New link should exist")
        link.tap()

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "What's New screen should open")

        _ = app.scrollToElementIfNeeded(AXID.whatsNewRow("notifications"))
        let notificationsRow = app.descendants(matching: .any)[AXID.whatsNewRow("notifications")].firstMatch
        XCTAssertTrue(
            notificationsRow.waitForExistence(timeout: 5),
            "Notifications row should exist in What's New"
        )
        notificationsRow.tap()

        let notificationsDetail = app.descendants(matching: .any)["whatsnew-detail-notifications"].firstMatch
        XCTAssertTrue(
            notificationsDetail.waitForExistence(timeout: 5),
            "Notifications detail should open from What's New"
        )

        let artwork = app.descendants(matching: .any)[AXID.whatsNewArtwork("notifications", style: "hero")].firstMatch
        XCTAssertTrue(
            artwork.waitForExistence(timeout: 5),
            "Notifications detail should show hero artwork"
        )
    }

    func testWhatsNewSleepDebtDetailExists() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsRowWhatsNew)

        let link = app.descendants(matching: .any)[AXID.settingsRowWhatsNew].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "What's New link should exist")
        link.tap()

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "What's New screen should open")

        _ = app.scrollToElementIfNeeded(AXID.whatsNewRow("sleepDebt"))
        let sleepDebtRow = app.descendants(matching: .any)[AXID.whatsNewRow("sleepDebt")].firstMatch
        XCTAssertTrue(
            sleepDebtRow.waitForExistence(timeout: 5),
            "Sleep Debt row should exist in What's New"
        )
        sleepDebtRow.tap()

        let sleepDebtDetail = app.descendants(matching: .any)["whatsnew-detail-sleepDebt"].firstMatch
        XCTAssertTrue(
            sleepDebtDetail.waitForExistence(timeout: 5),
            "Sleep Debt detail should open from What's New"
        )

        let artwork = app.descendants(matching: .any)[AXID.whatsNewArtwork("sleepDebt", style: "hero")].firstMatch
        XCTAssertTrue(
            artwork.waitForExistence(timeout: 5),
            "Sleep Debt detail should show hero artwork"
        )
    }

    func testWhatsNewWidgetDetailExists() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsRowWhatsNew)

        let link = app.descendants(matching: .any)[AXID.settingsRowWhatsNew].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "What's New link should exist")
        link.tap()

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "What's New screen should open")

        _ = app.scrollToElementIfNeeded(AXID.whatsNewRow("widgets"))
        let widgetsRow = app.descendants(matching: .any)[AXID.whatsNewRow("widgets")].firstMatch
        XCTAssertTrue(
            widgetsRow.waitForExistence(timeout: 5),
            "Widgets row should exist in What's New"
        )
        widgetsRow.tap()

        let widgetsDetail = app.descendants(matching: .any)["whatsnew-detail-widgets"].firstMatch
        XCTAssertTrue(
            widgetsDetail.waitForExistence(timeout: 5),
            "Widgets detail should open from What's New"
        )

        let artwork = app.descendants(matching: .any)[AXID.whatsNewArtwork("widgets", style: "hero")].firstMatch
        XCTAssertTrue(
            artwork.waitForExistence(timeout: 5),
            "Widgets detail should show hero artwork"
        )
    }

    func testWhatsNewMuscleMapDetailExists() throws {
        _ = app.scrollToElementIfNeeded(AXID.settingsRowWhatsNew)

        let link = app.descendants(matching: .any)[AXID.settingsRowWhatsNew].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "What's New link should exist")
        link.tap()

        let screen = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 5), "What's New screen should open")

        _ = app.scrollToElementIfNeeded(AXID.whatsNewRow("muscleMap"))
        let muscleMapRow = app.descendants(matching: .any)[AXID.whatsNewRow("muscleMap")].firstMatch
        XCTAssertTrue(
            muscleMapRow.waitForExistence(timeout: 5),
            "Muscle Map row should exist in What's New"
        )
        muscleMapRow.tap()

        let muscleMapDetail = app.descendants(matching: .any)["whatsnew-detail-muscleMap"].firstMatch
        XCTAssertTrue(
            muscleMapDetail.waitForExistence(timeout: 5),
            "Muscle Map detail should open from What's New"
        )

        let artwork = app.descendants(matching: .any)[AXID.whatsNewArtwork("muscleMap", style: "hero")].firstMatch
        XCTAssertTrue(
            artwork.waitForExistence(timeout: 5),
            "Muscle Map detail should show hero artwork"
        )
    }
}
