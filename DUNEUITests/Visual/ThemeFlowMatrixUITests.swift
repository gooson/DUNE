import XCTest

/// Checks the shared detail, sheet, and exercise surfaces in every theme.
@MainActor
final class ThemeFlowMatrixUITests: SeededUITestBaseCase {
    func testDesertWarmFlows() { captureTheme("desertWarm", named: "Desert") }
    func testOceanCoolFlows() { captureTheme("oceanCool", named: "Ocean") }
    func testForestGreenFlows() { captureTheme("forestGreen", named: "Forest") }
    func testSakuraCalmFlows() { captureTheme("sakuraCalm", named: "Sakura") }
    func testArcticDawnFlows() { captureTheme("arcticDawn", named: "Arctic") }
    func testSolarPopFlows() { captureTheme("solarPop", named: "Solar") }
    func testContourAtlasFlows() { captureTheme("contourAtlas", named: "Contour") }
    func testWaterLiliesFlows() { captureTheme("waterLilies", named: "Water Lilies") }

    private func captureTheme(_ rawValue: String, named themeName: String) {
        for style in ["Light", "Dark"] {
            let combination = "\(themeName) \(style)"

            launchTheme(rawValue, style: style)
            navigateToDashboard()
            let hero = app.descendants(matching: .any)[AXID.dashboardHeroCondition].firstMatch
            XCTAssertTrue(hero.waitForExistence(timeout: 15), "\(combination): condition hero")
            hero.tap()
            XCTAssertTrue(app.descendants(matching: .any)["condition-score-detail-screen"].firstMatch.waitForExistence(timeout: 10))
            addScreenshotAttachment(named: "\(combination) Detail")

            launchTheme(rawValue, style: style)
            navigateToWellness()
            XCTAssertTrue(app.waitAndTapToolbarAction("wellness-compare-metrics"), "\(combination): comparison action")
            XCTAssertTrue(app.descendants(matching: .any)["metric-comparison-first"].firstMatch.waitForExistence(timeout: 10))
            addScreenshotAttachment(named: "\(combination) Sheet")

            launchTheme(rawValue, style: style)
            navigateToActivity()
            XCTAssertTrue(app.waitAndTap(AXID.activityToolbarAdd), "\(combination): toolbar add action")
            XCTAssertTrue(app.descendants(matching: .any)["picker-root-list"].firstMatch.waitForExistence(timeout: 10))
            addScreenshotAttachment(named: "\(combination) Workout")
        }
    }

    private func launchTheme(_ rawValue: String, style: String) {
        app.terminate()
        app.launchArguments = launchConfiguration.launchArguments + [
            "--ui-test-theme", rawValue,
            "--ui-test-style", style.lowercased(),
            "-morningBriefingDisabled", "YES"
        ]
        app.launch()
        XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "\(rawValue) \(style): primary navigation")
    }
}
