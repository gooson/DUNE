@preconcurrency import XCTest

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

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func captureTheme(_ theme: String) throws {
        guard VisualAudit.isEnabled else { throw XCTSkip("Artist theme design capture requires a visual audit test plan") }

        for style in ["light", "dark"] {
            var configuration = launchConfiguration
            configuration.initialTabSelectionArgument = "today"
            configuration.additionalArguments += [
                "--ui-test-theme", theme, "--ui-test-style", style,
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
                "-morningBriefingDisabled", "YES"
            ]
            launchApp(with: configuration)
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
        let themeRow = "settings-theme-\(theme)"
        XCTAssertTrue(app.revealFullyVisible(themeRow, in: app.collectionViews.firstMatch, maxMoves: 20),
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
        open("activity-recent-workout-mock-workout-running-tempo", maxSwipes: 24)
        capture("W28", showing: AXID.healthkitWorkoutDetailScreen, prefix: prefix)
        goBack(to: "activity-recent-workout-mock-workout-running-tempo")

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
    }

    private func open(_ identifier: String, maxSwipes: Int = 0) {
        if maxSwipes > 0 {
            XCTAssertTrue(app.scrollToHittableElementIfNeeded(identifier, maxSwipes: maxSwipes),
                          "\(identifier) should be reachable")
        }
        let element = waitForElement(identifier, timeout: 15)
        XCTAssertTrue(element.isHittable, "\(identifier) should be hittable")
        element.tap()
    }

    private func goBack(to identifier: String) {
        let back = app.navigationBars.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 8) && back.isHittable, "Back button should be available")
        back.tap()
        _ = waitForElement(identifier, timeout: 10)
    }

    private func capture(_ screenID: String, showing identifier: String, prefix: String) {
        let landmark = waitForElement(identifier, timeout: 15)
        XCTAssertTrue(app.windows.firstMatch.frame.intersects(landmark.frame),
                      "\(screenID) should be rendered in the app viewport")
        VisualAudit.capture("\(prefix) \(screenID)")
    }
}
