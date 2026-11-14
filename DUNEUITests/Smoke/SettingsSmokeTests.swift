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
        openReleaseFromSettings()
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Manual release detail should have a back button")
        back.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch.waitForExistence(timeout: 5),
                      "Back should return to the News filter in Notifications")
    }

    func testWhatsNewNotificationsDetailShowsArtwork() throws {
        openReleaseFromSettings()

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
        openReleaseFromSettings()

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
        openReleaseFromSettings()

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
        openReleaseFromSettings()

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

    private func openReleaseFromSettings() {
        XCTAssertTrue(app.scrollToElementIfNeeded(AXID.settingsRowWhatsNew),
                      "What's New entry should remain reachable in Settings")
        let link = app.descendants(matching: .any)[AXID.settingsRowWhatsNew].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()

        let hub = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(hub.waitForExistence(timeout: 5), "Settings should open the notification hub")
        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        // Picker order is All, Health, News across localizations.
        let news = filter.buttons.element(boundBy: 2)
        XCTAssertTrue(news.waitForExistence(timeout: 5))
        XCTAssertTrue(news.isSelected, "Settings should enter with the News filter selected")

        let release = app.buttons[AXID.notificationsNewsRelease].firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: 5), "Current release should be available")
        release.tap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch.waitForExistence(timeout: 5),
                      "Manual release detail should open from News")
    }
}


/// Focused visual audit for the current release list and feature detail.
/// Kept separate from SettingsSmokeTests so its launch and navigation cannot
/// change the setup of the existing smoke cases.
@MainActor
final class WhatsNewVisualAuditTests: UITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testManualReleaseListOpensFeatureAndReturns() throws {
        openSettingsForAudit()
        openManualReleaseFromSettings()
        let release = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(release.staticTexts["0.8.0"].firstMatch.waitForExistence(timeout: 5),
                      "Current manual release retains its catalog version")
        let feature = app.descendants(matching: .any)[AXID.whatsNewRow("ios27Support")].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.whatsNewRow("ios27Support"), maxSwipes: 8),
                      "Current release feature stays reachable")
        XCTAssertTrue(feature.label.contains("iOS 27 Support"), "Feature keeps its supplied title")
        VisualAudit.capture("S05 manual release list")
        feature.auditTap()

        let detail = app.descendants(matching: .any)["whatsnew-detail-ios27Support"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Manual release opens its feature detail")
        XCTAssertTrue(app.descendants(matching: .any)[AXID.whatsNewArtwork("ios27Support", style: "hero")]
            .firstMatch.waitForExistence(timeout: 5), "Original feature artwork remains")
        XCTAssertFalse(app.buttons["whatsnew-close-button"].exists,
                       "Manual release uses native Back instead of Done")
        VisualAudit.capture("S06 manual feature detail")

        let detailBack = app.navigationBars["iOS 27 Support"].buttons["BackButton"].firstMatch
        XCTAssertTrue(detailBack.waitForExistence(timeout: 5) && detailBack.isHittable,
                      "Feature detail keeps native Back")
        detailBack.auditTap()
        XCTAssertTrue(release.waitForExistence(timeout: 5), "Back returns to the release list")
        let releaseBack = app.navigationBars["What's New"].buttons["BackButton"].firstMatch
        XCTAssertTrue(releaseBack.waitForExistence(timeout: 5) && releaseBack.isHittable,
                      "Release list keeps native Back")
        releaseBack.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch.waitForExistence(timeout: 5),
                      "Back returns to News in Notifications")
    }



    func testAutomaticReleaseDoneAtMaximumAccessibilitySize() throws {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "--force-automatic-whatsnew",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
        let release = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: 8), "Automatic release opens")
        let done = app.buttons["whatsnew-close-button"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5) && done.isHittable,
                      "S05 MAX automatic release keeps Done reachable")
        VisualAudit.capture("S05 MAX automatic release and Done")
        done.auditTap()
        XCTAssertTrue(release.waitForNonExistence(timeout: 5), "Done dismisses the automatic release")
    }



    func testManualReleaseListAndDetailAtMaximumAccessibilitySize() throws {
        relaunchAtMaximumTextSize()
        openSettingsForAudit()
        openManualReleaseFromSettings()
        let window = app.windows.firstMatch.frame
        let release = app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch
        let version = release.staticTexts["0.8.0"].firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 5), "S05 MAX shows the catalog version")
        XCTAssertGreaterThan(version.frame.width, 0)
        XCTAssertLessThanOrEqual(version.frame.maxX, window.maxX - 4,
                                 "S05 MAX version stays inside the window")
        VisualAudit.capture("S05 MAX version header")

        let feature = app.descendants(matching: .any)[AXID.whatsNewRow("ios27Support")].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.whatsNewRow("ios27Support"), maxSwipes: 8),
                      "S05 MAX feature row remains reachable")
        XCTAssertTrue(feature.label.contains("iOS 27 Support"), "S05 MAX keeps the full feature title")
        XCTAssertLessThanOrEqual(feature.frame.maxX, window.maxX - 4)
        VisualAudit.capture("S05 MAX feature row")
        feature.auditTap()

        let detail = app.descendants(matching: .any)["whatsnew-detail-ios27Support"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "S06 MAX feature detail opens")
        let title = detail.staticTexts["iOS 27 Support"].firstMatch
        let summary = detail.staticTexts["Refined for iOS 27, with the familiar experience you know."].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5) && summary.waitForExistence(timeout: 5),
                      "S06 MAX retains its supplied title and summary")
        XCTAssertLessThanOrEqual(title.frame.maxX, window.maxX - 4)
        XCTAssertLessThanOrEqual(summary.frame.maxX, window.maxX - 4)
        XCTAssertTrue(detail.staticTexts["0.8.0"].firstMatch.exists,
                      "S06 MAX retains the supplied version badge")
        VisualAudit.capture("S06 MAX feature header")
        for _ in 0..<4 where !summary.isHittable { detail.swipeUp() }
        XCTAssertTrue(summary.isHittable, "S06 MAX summary remains readable by scrolling")
        VisualAudit.capture("S06 MAX readable summary")
        let back = app.navigationBars["iOS 27 Support"].buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5) && back.isHittable,
                      "S06 MAX native Back stays reachable")
    }

    private func relaunchAtMaximumTextSize() {
        var configuration = launchConfiguration
        configuration.additionalArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchApp(with: configuration)
    }

    private func openSettingsForAudit() {
        navigateToDashboard()
        let settings = app.descendants(matching: .any)[AXID.dashboardToolbarSettings].firstMatch
        if settings.waitForExistence(timeout: 3) && settings.isHittable {
            settings.auditTap()
        } else {
            XCTAssertTrue(app.waitAndTapToolbarAction("Settings"),
                          "Settings should be available through native More")
        }
        XCTAssertTrue(app.navigationBars["Settings"].firstMatch.waitForExistence(timeout: 8),
                      "Settings opens from Today")
    }

    private func openManualReleaseFromSettings() {
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.settingsRowWhatsNew, maxSwipes: 12),
                      "What's New stays reachable in Settings")
        app.descendants(matching: .any)[AXID.settingsRowWhatsNew].firstMatch.auditTap()
        let hub = app.descendants(matching: .any)[AXID.notificationHubScreen].firstMatch
        XCTAssertTrue(hub.waitForExistence(timeout: 5), "Settings opens the notification hub")
        let filter = app.segmentedControls[AXID.notificationsFilter].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        let news = filter.buttons.element(boundBy: 2)
        XCTAssertTrue(news.waitForExistence(timeout: 5) && news.isSelected,
                      "Settings opens the News filter")
        let release = app.buttons[AXID.notificationsNewsRelease].firstMatch
        XCTAssertTrue(release.waitForExistence(timeout: 5), "Current release is available")
        release.auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.whatsNewScreen].firstMatch.waitForExistence(timeout: 5),
                      "Manual release opens from News")
    }
}
