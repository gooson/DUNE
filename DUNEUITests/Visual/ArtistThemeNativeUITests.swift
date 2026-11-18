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
    func testSakuraCalmDuoLight() throws { try captureTheme("sakuraCalm", styles: ["light"]) }
    func testSakuraCalmDuoDark() throws { try captureTheme("sakuraCalm", styles: ["dark"]) }

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
        let navigationBack = app.navigationBars.buttons["BackButton"].firstMatch
        let backButtons = app.buttons.matching(identifier: "BackButton")
        let ready = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                (navigationBack.exists && navigationBack.isHittable)
                    || backButtons.allElementsBoundByIndex.contains(where: \.isHittable)
            }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 8),
                       .completed, "Back button should be available")
        if navigationBack.exists && navigationBack.isHittable {
            navigationBack.tap()
        } else {
            let floatingButtons = backButtons.allElementsBoundByIndex.filter(\.isHittable)
            XCTAssertEqual(floatingButtons.count, 1, "Duo should show one floating Back button")
            floatingButtons.first?.tap()
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
