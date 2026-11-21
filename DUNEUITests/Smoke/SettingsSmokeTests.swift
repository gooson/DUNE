@preconcurrency import XCTest
import UIKit

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
        openSettingsCategory(AXID.settingsHubWorkout)
        XCTAssertTrue(
            elementExists(AXID.settingsRowRestTime, timeout: 5),
            "Rest Time setting row should exist"
        )
    }

    func testBedtimeReminderSettingsExist() throws {
        openSettingsCategory(AXID.settingsHubAlerts)
        openSettingsCategory(AXID.settingsLinkBedtime)
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
        _ = app.scrollToHittableElementIfNeeded(AXID.settingsRowAppleWatchBedtimeReminderLeadTime)
        addScreenshotAttachment(named: defaultArtifactName(suffix: "bedtime-settings"))
    }

    func testPostureReminderExists() throws {
        openSettingsCategory(AXID.settingsHubAlerts)
        openSettingsCategory("settings-link-otherAlerts")
        XCTAssertTrue(elementExists(AXID.settingsRowPostureReminder, timeout: 5))
    }

    func testExerciseDefaultsLinkExists() throws {
        openSettingsCategory(AXID.settingsHubWorkout)
        XCTAssertTrue(
            elementExists(AXID.settingsRowExerciseDefaults, timeout: 5),
            "Exercise Defaults navigation link should exist"
        )
    }

    func testPreferredExercisesLinkExists() throws {
        openSettingsCategory(AXID.settingsHubWorkout)
        XCTAssertTrue(
            elementExists(AXID.settingsRowPreferredExercises, timeout: 5),
            "Preferred Exercises navigation link should exist"
        )
    }

    func testNavigateToExerciseDefaults() throws {
        openSettingsCategory(AXID.settingsHubWorkout)
        let link = app.descendants(matching: .any)[AXID.settingsRowExerciseDefaults].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Exercise Defaults link should exist")
        link.tap()

        XCTAssertTrue(elementExists(AXID.exerciseDefaultsScreen, timeout: 5),
                      "Exercise Defaults screen should open")
    }

    func testNavigateToPreferredExercises() throws {
        openSettingsCategory(AXID.settingsHubWorkout)
        let link = app.descendants(matching: .any)[AXID.settingsRowPreferredExercises].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Preferred Exercises link should exist")
        link.tap()

        XCTAssertTrue(elementExists(AXID.preferredExercisesScreen, timeout: 5),
                      "Preferred Exercises screen should open")
    }

    func testAppearanceSectionExists() throws {
        XCTAssertTrue(
            elementExists(AXID.settingsSectionAppearance, timeout: 5),
            "Appearance gallery entry should exist"
        )
    }

    func testThemePreviewCancelAndApply() throws {
        let gallery = AXID.settingsSectionAppearance
        XCTAssertTrue(elementExists(gallery, timeout: 5))
        addScreenshotAttachment(named: "S01-settings-home")
        openSettingsCategory(gallery)
        let themeID = "settings-theme-patisserie"
        XCTAssertTrue(app.revealFullyVisible(
            themeID, in: app.scrollViews[AXID.settingsThemeGallery].firstMatch, maxMoves: 20
        ))
        addScreenshotAttachment(named: "S01-theme-gallery")
        app.buttons[themeID].auditTap()
        XCTAssertTrue(elementExists(AXID.settingsThemeApply, timeout: 5))
        XCTAssertTrue(elementExists(AXID.settingsPreviewLight, timeout: 5))
        addScreenshotAttachment(named: "S01-theme-preview-light")
        app.descendants(matching: .any)[AXID.settingsPreviewDark].firstMatch.auditTap()
        addScreenshotAttachment(named: "S01-theme-preview-dark")

        let back = app.navigationBars.buttons["BackButton"].firstMatch.exists
            ? app.navigationBars.buttons["BackButton"].firstMatch
            : app.navigationBars.buttons.element(boundBy: 0)
        let detailBack = app.buttons[AXID.settingsDetailBack].firstMatch
        if detailBack.exists && detailBack.isHittable {
            detailBack.auditTap()
        } else {
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            back.auditTap()
        }
        XCTAssertTrue(app.buttons[themeID].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[themeID].isSelected, "Preview cancellation must not save the candidate")

        app.buttons[themeID].auditTap()
        XCTAssertTrue(app.descendants(matching: .any)[AXID.settingsThemeApply].firstMatch.waitForExistence(timeout: 5))
        app.descendants(matching: .any)[AXID.settingsThemeApply].firstMatch.auditTap()
        dismissIconConfirmation()
        XCTAssertTrue(app.buttons[themeID].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[themeID].isSelected, "Apply should save the chosen theme")

        openSettingsCategory(AXID.settingsRowAppIcon)
        let palette = app.staticTexts["settings-app-icon-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 5))
        XCTAssertTrue(["로즈 × 크림", "Rose × Cream", "ローズ × クリーム"].contains(palette.label),
                      "Expected the selected Patisserie palette, got \(palette.label)")
    }

    func testSearchBedtimeEmptyResultsAndReturn() throws {
        openSettingsCategory(AXID.settingsHubSearch)
        let field = app.textFields[AXID.settingsSearchField].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.auditTap()
        field.typeText("bedtime")
        let bedtime = app.descendants(matching: .any)[AXID.settingsSearchResult("bedtime")].firstMatch
        XCTAssertTrue(bedtime.waitForExistence(timeout: 5))
        addScreenshotAttachment(named: "S01-settings-search-bedtime")
        bedtime.auditTap()
        XCTAssertTrue(elementExists(AXID.settingsRowBedtimeReminder, timeout: 5))
        addScreenshotAttachment(named: "S01-settings-bedtime-detail")

        let back = app.navigationBars.buttons["BackButton"].firstMatch.exists
            ? app.navigationBars.buttons["BackButton"].firstMatch
            : app.navigationBars.buttons.element(boundBy: 0)
        let detailBack = app.buttons[AXID.settingsDetailBack].firstMatch
        if detailBack.exists && detailBack.isHittable { detailBack.auditTap() } else { back.auditTap() }
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "bedtime", "Back should retain the search query")
        field.auditTap()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("zz-no-matching-setting")
        XCTAssertFalse(bedtime.exists)
        addScreenshotAttachment(named: "S01-settings-search-empty")
    }

    func testSearchThemeApplyReturnsToGallery() throws {
        openSettingsCategory(AXID.settingsHubSearch)
        let field = app.textFields[AXID.settingsSearchField].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.auditTap()
        field.typeText("patisserie")
        let result = app.buttons[AXID.settingsSearchResult("theme-patisserie")].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.auditTap()
        let apply = app.buttons[AXID.settingsThemeApply].firstMatch
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        apply.auditTap()
        dismissIconConfirmation()
        let gallery = app.scrollViews[AXID.settingsThemeGallery].firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 5), "Apply should open the gallery")
        let themeID = "settings-theme-patisserie"
        XCTAssertTrue(app.revealFullyVisible(themeID, in: gallery, maxMoves: 20))
        XCTAssertTrue(app.buttons[themeID].firstMatch.isSelected)
    }

    func testCategoryDetailsOpenFromHub() throws {
        openSettingsCategory(AXID.settingsHubWorkout)
        XCTAssertTrue(elementExists(AXID.settingsRowRestTime, timeout: 5))
        addScreenshotAttachment(named: "S01-settings-workout")
        openSettingsCategory(AXID.settingsHubPrivacy)
        XCTAssertTrue(elementExists(AXID.settingsRowICloudSync, timeout: 5))
        addScreenshotAttachment(named: "S01-settings-privacy")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(elementExists(AXID.settingsHubHome, timeout: 5), "Split layout keeps the hub visible")
        }
    }

    func testDataPrivacySectionExists() throws {
        openSettingsCategory(AXID.settingsHubPrivacy)
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
        openSettingsCategory(AXID.settingsHubMockData)
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
        openSettingsCategory(AXID.settingsHubAbout)
        _ = app.scrollToElementIfNeeded(AXID.settingsRowVersion)
        XCTAssertTrue(
            elementExists(AXID.settingsRowVersion, timeout: 5),
            "Version row should exist"
        )
    }

    func testWhatsNewLinkExists() throws {
        openSettingsCategory(AXID.settingsHubAbout)
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
        openSettingsCategory(AXID.settingsHubAbout)
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


@MainActor
final class SettingsHubKoreanCaptureTests: UITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR", "--ui-test-style", "light"]
    }

    func testKoreanHubGalleryPreviewAndDetails() {
        navigateToSettings()
        XCTAssertTrue(elementExists(AXID.settingsHubHome, timeout: 5))
        addScreenshotAttachment(named: "S01-ko-settings-home")

        openSettingsCategory(AXID.settingsSectionAppearance)
        let gallery = app.scrollViews[AXID.settingsThemeGallery].firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))
        addScreenshotAttachment(named: "S01-ko-theme-gallery")
        XCTAssertTrue(app.revealFullyVisible(
            "settings-theme-patisserie", in: gallery, maxMoves: 20
        ))
        app.buttons["settings-theme-patisserie"].auditTap()
        XCTAssertTrue(elementExists(AXID.settingsThemeApply, timeout: 5))
        addScreenshotAttachment(named: "S01-ko-theme-preview-light")
        app.descendants(matching: .any)[AXID.settingsPreviewDark].firstMatch.auditTap()
        addScreenshotAttachment(named: "S01-ko-theme-preview-dark")

        openSettingsCategory(AXID.settingsHubWorkout)
        XCTAssertTrue(elementExists(AXID.settingsRowRestTime, timeout: 5))
        addScreenshotAttachment(named: "S01-ko-workout-detail")
        openSettingsCategory(AXID.settingsHubPrivacy)
        XCTAssertTrue(elementExists(AXID.settingsRowICloudSync, timeout: 5))
        addScreenshotAttachment(named: "S01-ko-privacy-detail")
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
        let release = app.scrollViews[AXID.whatsNewScreen].firstMatch
        XCTAssertTrue(release.staticTexts["0.9.0"].firstMatch.waitForExistence(timeout: 5),
                      "Current manual release retains its catalog version")
        let feature = app.descendants(matching: .any)[AXID.whatsNewRow("artistThemes")].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.whatsNewRow("artistThemes"), maxSwipes: 8),
                      "Current release feature stays reachable")
        XCTAssertTrue(feature.label.contains("Nine Artist Themes"), "Feature keeps its supplied title")
        let captureDuo = ProcessInfo.processInfo.environment["DUNE_VISUAL_AUDIT_FOLD"] == "1"
        if captureDuo {
            VisualAudit.capture("FOLD:closed S05 release list")
            VisualAudit.capture("FOLD:openFlat S05 release list")
            reassertDuoOpenLandscapeIfNeeded()
        }
        VisualAudit.capture("S05 manual release list")
        feature.auditTap()

        let detail = app.scrollViews["whatsnew-detail-artistThemes"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "Manual release opens its feature detail")
        XCTAssertTrue(app.descendants(matching: .any)[AXID.whatsNewArtwork("artistThemes", style: "hero")]
            .firstMatch.waitForExistence(timeout: 5), "Original feature artwork remains")
        XCTAssertFalse(app.buttons["whatsnew-close-button"].exists,
                       "Manual release uses native Back instead of Done")
        VisualAudit.capture("S06 manual feature detail")
        if captureDuo {
            VisualAudit.capture("FOLD:closed S06 feature detail")
        }

        let detailBack = captureDuo
            ? app.buttons["BackButton"].firstMatch
            : app.navigationBars["Nine Artist Themes"].buttons["BackButton"].firstMatch
        XCTAssertTrue(detailBack.waitForExistence(timeout: 5) && detailBack.isHittable,
                      "Feature detail keeps native Back")
        detailBack.auditTap()
        XCTAssertTrue(release.waitForExistence(timeout: 5), "Back returns to the release list")
        let releaseBack = captureDuo
            ? app.buttons["BackButton"].firstMatch
            : app.navigationBars["What's New"].buttons["BackButton"].firstMatch
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
        let release = app.scrollViews[AXID.whatsNewScreen].firstMatch
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
        let release = app.scrollViews[AXID.whatsNewScreen].firstMatch
        let version = release.staticTexts["0.9.0"].firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 5), "S05 MAX shows the catalog version")
        XCTAssertGreaterThan(version.frame.width, 0)
        XCTAssertLessThanOrEqual(version.frame.maxX, window.maxX - 4,
                                 "S05 MAX version stays inside the window")
        VisualAudit.capture("S05 MAX version header")

        let feature = app.descendants(matching: .any)[AXID.whatsNewRow("artistThemes")].firstMatch
        XCTAssertTrue(app.scrollToHittableElementIfNeeded(AXID.whatsNewRow("artistThemes"), maxSwipes: 8),
                      "S05 MAX feature row remains reachable")
        XCTAssertTrue(feature.label.contains("Nine Artist Themes"), "S05 MAX keeps the full feature title")
        XCTAssertLessThanOrEqual(feature.frame.maxX, window.maxX - 4)
        VisualAudit.capture("S05 MAX feature row")
        feature.auditTap()

        let detail = app.scrollViews["whatsnew-detail-artistThemes"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "S06 MAX feature detail opens")
        let title = detail.staticTexts["Nine Artist Themes"].firstMatch
        let summary = detail.staticTexts["Choose a theme for your health screens and change the app icon in Settings."].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5) && summary.waitForExistence(timeout: 5),
                      "S06 MAX retains its supplied title and summary")
        XCTAssertLessThanOrEqual(title.frame.maxX, window.maxX - 4)
        XCTAssertLessThanOrEqual(summary.frame.maxX, window.maxX - 4)
        XCTAssertTrue(detail.staticTexts["0.9.0"].firstMatch.exists,
                      "S06 MAX retains the supplied version badge")
        VisualAudit.capture("S06 MAX feature header")
        for _ in 0..<4 where !summary.isHittable { detail.swipeUp() }
        XCTAssertTrue(summary.isHittable, "S06 MAX summary remains readable by scrolling")
        VisualAudit.capture("S06 MAX readable summary")
        let back = app.navigationBars["Nine Artist Themes"].buttons["BackButton"].firstMatch
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
        openSettingsCategory(AXID.settingsHubAbout)
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
        VisualAudit.capture("T11 current release in News")
        release.auditTap()
        XCTAssertTrue(app.scrollViews[AXID.whatsNewScreen].firstMatch.waitForExistence(timeout: 5),
                      "Manual release opens from News")
    }
}
