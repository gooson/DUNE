import XCTest

/// Captures the four primary scenes for each existing theme in both appearances.
@MainActor
final class ThemeMatrixUITests: SeededUITestBaseCase {
    func testDesertWarmMatrix() {
        captureTheme("desertWarm", named: "Desert")

        navigateToWellness()
        let sleepDetail = app.descendants(matching: .any)["wellness-sleep-detail-link"].firstMatch
        XCTAssertTrue(sleepDetail.waitForExistence(timeout: 10), "Desert sleep detail action should load")
        sleepDetail.tap()
        let sleepQuality = app.descendants(matching: .any)["sleep-section-quality"].firstMatch
        XCTAssertTrue(sleepQuality.waitForExistence(timeout: 10), "Sleep action should open sleep metric details")
    }

    func testDesertWellnessRingLayout() {
        for style in ["Light", "Dark"] {
            app.terminate()
            app.launchArguments = launchConfiguration.launchArguments + [
                "--ui-test-theme", "desertWarm",
                "--ui-test-style", style.lowercased(),
                "-morningBriefingDisabled", "YES"
            ]
            app.launch()
            navigateToWellness()

            let hero = app.descendants(matching: .any)["wellness-hero-score"].firstMatch
            let narrative = app.descendants(matching: .any)["wellness-hero-narrative"].firstMatch
            XCTAssertTrue(hero.waitForExistence(timeout: 10))
            XCTAssertTrue(narrative.waitForExistence(timeout: 10))
            XCTAssertLessThanOrEqual(narrative.frame.maxX, hero.frame.maxX + 1)
            addScreenshotAttachment(named: "Desert \(style) Wellness Ring Layout")
        }
    }

    func testOceanCoolMatrix() {
        captureTheme("oceanCool", named: "Ocean")
    }

    func testForestGreenMatrix() {
        captureTheme("forestGreen", named: "Forest")
    }

    func testSakuraCalmMatrix() {
        captureTheme("sakuraCalm", named: "Sakura")
    }

    func testArcticDawnMatrix() {
        captureTheme("arcticDawn", named: "Arctic")
    }

    func testSolarPopMatrix() {
        captureTheme("solarPop", named: "Solar")
    }

    func testContourAtlasMatrix() {
        captureTheme("contourAtlas", named: "Contour")
    }

    private func captureTheme(_ rawValue: String, named themeName: String) {
        for style in ["Light", "Dark"] {
            app.terminate()
            app.launchArguments = launchConfiguration.launchArguments + [
                "--ui-test-theme", rawValue,
                "--ui-test-style", style.lowercased(),
                "-morningBriefingDisabled", "YES"
            ]
            app.launch()

            let combination = "\(themeName) \(style)"
            XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "\(combination): primary navigation should load")
            captureRoots(for: combination)
        }
    }

    private func captureRoots(for combination: String) {
        navigateToDashboard()
        captureRoot(AXID.dashboardHeroCondition, tab: "Today", combination: combination)
        assertRing("dashboard-hero-ring", combination: combination)
        assertAction("dashboard-primary-activity", combination: combination)

        navigateToActivity()
        captureRoot(AXID.activityHeroReadiness, tab: "Activity", combination: combination)
        assertRing("activity-hero-ring", combination: combination)
        assertAction("activity-log-workout-button", combination: combination)

        navigateToWellness()
        captureRoot(AXID.wellnessHeroScore, tab: "Wellness", combination: combination)
        assertRing("wellness-hero-ring", combination: combination)
        assertAction("wellness-sleep-detail-link", combination: combination)

        navigateToLife()
        captureRoot(AXID.lifeHeroProgress, tab: "Life", combination: combination)
        assertRing("life-hero-ring", combination: combination)
        assertAction("life-hero-checklist-button", combination: combination)
    }

    private func captureRoot(_ identifier: String, tab: String, combination: String) {
        let root = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 10), "\(combination) \(tab): \(identifier) should load")
        addScreenshotAttachment(named: "\(combination) \(tab)")
    }

    private func assertAction(_ identifier: String, combination: String) {
        let action = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 10), "\(combination): \(identifier) should load")
    }

    private func assertRing(_ identifier: String, combination: String) {
        let ring = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 10), "\(combination): \(identifier) should show the tab score ring")
    }
}
