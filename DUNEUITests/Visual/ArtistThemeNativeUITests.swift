@preconcurrency import XCTest
import UIKit

/// Captures the production routes shown in the artist theme gallery.
@MainActor
final class ArtistThemeNativeUITests: ActivityExerciseSeededUITestBaseCase {
    func testDesertWarm() throws { try captureTheme("desertWarm") }
    func testOceanCool() throws { try captureTheme("oceanCool") }
    func testForestGreen() throws { try captureTheme("forestGreen") }
    func testSakuraCalm() throws { try captureTheme("sakuraCalm") }
    func testArcticDawn() throws { try captureTheme("arcticDawn") }
    func testSolarPop() throws { try captureTheme("solarPop") }
    func testContourAtlas() throws { try captureTheme("contourAtlas") }
    func testWaterLilies() throws { try captureTheme("waterLilies") }
    func testPatisserie() throws { try captureTheme("patisserie") }
    func testSakuraCalmDuoLight() throws { try captureTheme("sakuraCalm", styles: ["light"]) }
    func testSakuraCalmDuoDark() throws { try captureTheme("sakuraCalm", styles: ["dark"]) }

    private func captureThemeScreen(_ name: String) {
        if VisualAudit.isEnabled {
            VisualAudit.capture(name)
        } else {
            addScreenshotAttachment(named: name)
        }
    }

    func testOceanDarkHeaderAndThemePreviewButton() {
        launchApp(with: themeLaunchConfiguration("oceanCool", style: "dark"))
        reassertDuoOpenLandscapeIfNeeded()
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        dismissIconConfirmation()
        navigateToDashboard()
        _ = waitForElement(AXID.dashboardHeroCondition, timeout: 15)
        captureThemeScreen("T03-ocean-dark")
        open(AXID.dashboardHeroCondition)
        _ = waitForElement(AXID.conditionScoreDetailScreen)
        captureThemeScreen("T04-ocean-dark")
        goBack(to: AXID.dashboardHeroCondition)
        navigateToSettings()
        openSettingsCategory(AXID.settingsSectionAppearance)

        let gallery = app.scrollViews[AXID.settingsThemeGallery].firstMatch
        for (theme, isCurrent) in [("oceanCool", true), ("forestGreen", false)] {
            let identifier = "settings-theme-\(theme)"
            XCTAssertTrue(app.revealFullyVisible(identifier, in: gallery, maxMoves: 8))
            app.buttons[identifier].firstMatch.auditTap()
            let action = app.buttons[AXID.settingsThemeApply].firstMatch
            XCTAssertTrue(action.waitForExistence(timeout: 5))
            let sample = app.descendants(matching: .any)["settings-theme-sample"].firstMatch
            XCTAssertEqual(action.frame.minY - sample.frame.maxY, 16, accuracy: 1)
            let scroll = app.scrollViews["settings-theme-preview-scroll"].firstMatch
            // The appearance picker shares the visible card edges, including on Duo's inset viewport.
            let picker = app.otherElements["Today preview appearance"].firstMatch
            XCTAssertEqual(action.frame.minX, picker.frame.minX, accuracy: 1)
            XCTAssertEqual(action.frame.maxX, picker.frame.maxX, accuracy: 1)
            XCTAssertGreaterThanOrEqual(action.frame.height, 52)
            if !app.windows.firstMatch.frame.contains(action.frame) {
                scroll.swipeUp()
            }
            XCTAssertTrue(app.windows.firstMatch.frame.contains(action.frame))
            XCTAssertEqual(action.isEnabled, !isCurrent)
            XCTAssertEqual(action.label, isCurrent ? "Current theme" : "Apply this theme")
            captureThemeScreen("S01-\(theme)-dark")
            if isCurrent { settingsBackButton.auditTap() }
        }
    }

    func testOceanCoolDuoDarkWorkout() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Workout detail capture requires a visual audit test plan") }
        var configuration = themeLaunchConfiguration("oceanCool", style: "dark")
        configuration.initialTabSelectionArgument = "train"
        launchApp(with: configuration)
        reassertDuoOpenLandscapeIfNeeded()
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        dismissIconConfirmation()
        captureImportedWorkout(prefix: "Artist oceanCool dark")
    }

    func testPatisserieLightWorkoutModalNavigation() throws {
        try capturePatisserieWorkoutModals(style: "light")
    }

    func testPatisserieDarkWorkoutModalNavigation() throws {
        try capturePatisserieWorkoutModals(style: "dark")
    }

    func testPatisserieDarkModalHeadersAcrossTabs() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Modal capture requires a visual audit test plan") }
        var configuration = themeLaunchConfiguration("patisserie", style: "dark")
        configuration.initialTabSelectionArgument = "train"
        launchApp(with: configuration)
        dismissIconConfirmation()

        navigateToActivity()
        XCTAssertTrue(app.waitAndTapToolbarAction(AXID.activityToolbarAdd))
        capture("W02", showing: AXID.pickerRootList, prefix: "Artist patisserie dark modal")
        closeModal(AXID.pickerCancelButton)

        navigateToWellness()
        XCTAssertTrue(app.waitAndTapToolbarAction(AXID.wellnessToolbarAdd))
        open(AXID.wellnessMenuBodyRecord)
        capture("H05", showing: "body-form-screen", prefix: "Artist patisserie dark modal")
        XCTAssertTrue(app.buttons["body-form-save"].firstMatch.exists)
        closeModal("body-form-cancel")

        navigateToLife()
        XCTAssertTrue(app.openLifeNewHabitForm())
        capture("L02", showing: AXID.habitFormName, prefix: "Artist patisserie dark modal")
        XCTAssertTrue(app.buttons[AXID.habitFormSave].firstMatch.exists)
        closeModal("habit-form-cancel")
    }

    private func closeModal(_ identifier: String) {
        let close = app.buttons[identifier].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5) && close.isHittable)
        close.auditTap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
    }

    private func capturePatisserieWorkoutModals(style: String) throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Workout modal capture requires a visual audit test plan") }
        var configuration = themeLaunchConfiguration("patisserie", style: style)
        configuration.initialTabSelectionArgument = "train"
        launchApp(with: configuration)
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        dismissIconConfirmation()

        navigateToActivity()
        open(AXID.activityRecentSeeAll, maxSwipes: 24)
        let list = waitForElement(AXID.exerciseViewScreen, timeout: 10)
        let rowID = AXID.exerciseRow("mock-workout-running-tempo")
        open(rowID, maxSwipes: 12)

        let detail = waitForElement(AXID.healthkitWorkoutDetailScreen, timeout: 10)
        let close = app.buttons["exercise-inspector-close"].firstMatch
        let edit = app.buttons[AXID.healthkitWorkoutEditTitle].firstMatch
        let title = app.navigationBars.staticTexts["Tempo Run"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5) && close.isHittable)
        XCTAssertTrue(edit.waitForExistence(timeout: 5) && edit.isHittable)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(close.label, "Close")
        XCTAssertLessThan(abs(close.frame.midY - title.frame.midY), 16)
        XCTAssertLessThan(abs(edit.frame.midY - title.frame.midY), 16)
        capture("W28", showing: AXID.healthkitWorkoutDetailScreen,
                prefix: "Artist patisserie \(style) modal")

        edit.auditTap()
        _ = waitForElement(AXID.healthkitWorkoutTitleEditorScreen, timeout: 8)
        capture("W33", showing: AXID.healthkitWorkoutTitleEditorScreen,
                prefix: "Artist patisserie \(style) modal")
        let cancel = app.buttons[AXID.healthkitWorkoutTitleCancel].firstMatch
        cancel.auditTap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(detail.waitForExistence(timeout: 8) && detail.isHittable)

        // The seeded Tempo Run already exposes Atlas actions without a separate location fixture.
        for (action, screen, name) in [
            ("cardio-atlas-journey", "cardio-atlas-journey-detail", "Atlas Journey"),
            ("cardio-atlas-passport", "cardio-atlas-passport-detail", "Atlas Passport")
        ] {
            open(action, maxSwipes: 12)
            let destination = waitForElement(screen, timeout: 10)
            XCTAssertTrue(app.windows.firstMatch.frame.intersects(destination.frame))
            captureThemeScreen("Artist patisserie \(style) modal \(name)")
            let destinationClose = app.buttons["cardio-atlas-destination-close"].firstMatch
            destinationClose.auditTap()
            XCTAssertTrue(destinationClose.waitForNonExistence(timeout: 5))
            XCTAssertTrue(detail.waitForExistence(timeout: 8) && detail.isHittable)
        }

        close.auditTap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let row = waitForElement(rowID, timeout: 5)
        XCTAssertTrue(row.isHittable)
        capture("W01", showing: rowID, prefix: "Artist patisserie \(style) modal")
        row.auditTap()
        XCTAssertTrue(detail.waitForExistence(timeout: 8))
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.auditTap()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWeeklyReportReadingInk() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Weekly report capture requires a visual audit test plan") }
        executionTimeAllowance = 600
        for theme in ["forestGreen", "oceanCool", "sakuraCalm"] {
            for style in ["light", "dark"] {
                var configuration = themeLaunchConfiguration(theme, style: style)
                configuration.initialTabSelectionArgument = "life"
                launchApp(with: configuration)
                XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
                dismissIconConfirmation()
                navigateToLife()
                open("life-weekly-report-button", maxSwipes: 16)
                let report = app.scrollViews["life-weekly-report-scroll"].firstMatch
                let supportingHeading = waitForElement("life-weekly-report-improvement", timeout: 8)
                let smallRate = report.staticTexts["14%"].firstMatch
                XCTAssertTrue(smallRate.waitForExistence(timeout: 8))
                let viewport = report.frame.intersection(app.windows.firstMatch.frame)
                XCTAssertTrue(viewport.contains(supportingHeading.frame) && viewport.contains(smallRate.frame),
                              "The report screenshot must show the supporting heading and small habit rate")
                capture("L08", showing: "life-weekly-report-rate", prefix: "Artist \(theme) \(style)")
            }
        }
    }

    func testOceanMotionKeepsContentAnchored() throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Ocean motion capture requires a visual audit test plan") }
        XCTAssertFalse(UIAccessibility.isReduceMotionEnabled, "The owner simulator must allow decorative motion")
        XCTAssertFalse(ProcessInfo.processInfo.isLowPowerModeEnabled)
        app = XCUIApplication()
        app.launchArguments = themeLaunchConfiguration("oceanCool", style: "light").launchArguments
            .filter { $0 != "--ui-disable-animations" }
        app.launch()
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15))
        dismissIconConfirmation()

        navigateToDashboard()
        captureOceanMotion("T03", score: AXID.dashboardHeroCondition, control: AXID.dashboardToolbarSettings)
        open(AXID.dashboardHeroCondition)
        _ = waitForElement(AXID.conditionScoreDetailScreen, timeout: 15)
        captureOceanMotion("T04", score: "condition-detail-hero-ring", control: "BackButton")
    }

    private func captureOceanMotion(_ screen: String, score: String, control: String) {
        let scoreElement = waitForElement(score, timeout: 15)
        let controlElement = waitForElement(control, timeout: 15)
        VisualAudit.capture("Artist oceanCool motion \(screen) frame 1")
        let scoreFrame = scoreElement.frame
        let scoreLabel = scoreElement.label
        let controlFrame = controlElement.frame
        XCTAssertFalse(scoreLabel.isEmpty)
        XCTAssertTrue(app.windows.firstMatch.frame.intersects(scoreFrame))
        XCTAssertTrue(controlElement.isHittable)
        for frame in 2...3 {
            VisualAudit.capture("Artist oceanCool motion \(screen) frame \(frame)")
            XCTAssertEqual(scoreElement.frame, scoreFrame)
            XCTAssertEqual(scoreElement.label, scoreLabel)
            XCTAssertEqual(controlElement.frame, controlFrame)
            XCTAssertTrue(controlElement.isHittable)
        }
    }

    private func themeLaunchConfiguration(_ theme: String, style: String) -> LaunchConfiguration {
        var configuration = launchConfiguration
        configuration.initialTabSelectionArgument = "today"
        configuration.additionalArguments += [
            "--ui-test-theme", theme, "--ui-test-style", style,
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
            "-morningBriefingDisabled", "YES"
        ]
        return configuration
    }

    private func captureTheme(_ theme: String, styles: [String] = ["light", "dark"]) throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Artist theme design capture requires a visual audit test plan") }
        // The host audit holds each of the ten native routes while both displays are saved.
        executionTimeAllowance = 600

        for style in styles {
            launchApp(with: themeLaunchConfiguration(theme, style: style))
            reassertDuoOpenLandscapeIfNeeded()
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "Primary navigation for \(theme) \(style)")
            dismissIconConfirmation()
            captureScenes(prefix: "Artist \(theme) \(style)", theme: theme)
        }
    }

    private func captureScenes(prefix: String, theme: String) {
        navigateToDashboard()
        open(AXID.dashboardToolbarSettings)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        openSettingsCategory(AXID.settingsSectionAppearance)
        let themeRow = "settings-theme-\(theme)"
        XCTAssertTrue(app.revealFullyVisible(themeRow, in: app.scrollViews[AXID.settingsThemeGallery].firstMatch, maxMoves: 20),
                      "Settings preview for \(theme) should be visible")
        XCTAssertTrue(app.buttons[themeRow].firstMatch.isSelected, "Settings should report \(theme) as selected")
        capture("S01", showing: themeRow, prefix: prefix)
        goBack(to: AXID.dashboardHeroCondition)

        capture("T03", showing: AXID.dashboardHeroCondition, prefix: prefix)
        open(AXID.dashboardHeroCondition)
        capture("T04", showing: AXID.conditionScoreDetailScreen, prefix: prefix)
        goBack(to: AXID.dashboardHeroCondition)

        navigateToActivity()
        capture("A01", showing: AXID.activityHeroReadiness, prefix: prefix)
        open(AXID.activityHeroReadiness)
        capture("A02", showing: AXID.activityTrainingReadinessDetailScreen, prefix: prefix)
        goBack(to: AXID.activityHeroReadiness)

        navigateToLife()
        capture("L01", showing: AXID.lifeHeroProgress, prefix: prefix)
        open("life-weekly-report-button", maxSwipes: 16)
        capture("L08", showing: "life-weekly-report-rate", prefix: prefix)
        goBack(to: "life-weekly-report-button")

        navigateToWellness()
        capture("H01", showing: AXID.wellnessHeroScore, prefix: prefix)
        open(AXID.wellnessHeroScore)
        capture("H02", showing: AXID.wellnessScoreDetailScreen, prefix: prefix)
        goBack(to: AXID.wellnessHeroScore)
        open("wellness-hero-sleep", maxSwipes: 12)
        capture("T06", showing: AXID.metricDetailScreen("sleep"), prefix: prefix)
        goBack(to: "wellness-hero-sleep")

        captureImportedWorkout(prefix: prefix)
    }

    private func captureImportedWorkout(prefix: String) {
        navigateToActivity()
        open(AXID.activityRecentSeeAll, maxSwipes: 24)
        _ = waitForElement(AXID.exerciseViewScreen, timeout: 10)
        open(AXID.exerciseRow("mock-workout-running-tempo"), maxSwipes: 12)
        capture("W28", showing: AXID.healthkitWorkoutDetailScreen, prefix: prefix)
    }

    private func open(_ identifier: String, maxSwipes: Int = 0) {
        if maxSwipes > 0 {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(identifier, maxSwipes: maxSwipes, timeoutPerCheck: 0.25),
                          "\(identifier) should be reachable")
        }
        let element = waitForElement(identifier, timeout: 15)
        XCTAssertTrue(element.isHittable, "\(identifier) should be hittable")
        element.tap()
    }

    private func goBack(to identifier: String) {
        let target = app.descendants(matching: .any)[identifier].firstMatch
        for _ in 0..<3 where !target.exists {
            let native = app.navigationBars.buttons["BackButton"].firstMatch
            let floating = app.buttons.matching(identifier: "BackButton")
                .allElementsBoundByIndex.first(where: \.isHittable)
            let detail = app.buttons[AXID.settingsDetailBack].firstMatch
            if native.exists && native.isHittable {
                native.auditTap()
            } else if let floating {
                floating.auditTap()
            } else if detail.exists && detail.isHittable {
                detail.auditTap()
            } else {
                XCTFail("Back button should be available")
                return
            }
        }
        _ = waitForElement(identifier, timeout: 10)
    }

    private func capture(_ screenID: String, showing identifier: String, prefix: String) {
        let landmark = waitForElement(identifier, timeout: 15)
        XCTAssertTrue(app.windows.firstMatch.frame.intersects(landmark.frame),
                      "\(screenID) should be rendered in the app viewport")
        VisualAudit.capture("\(prefix) \(screenID)")
    }
}
