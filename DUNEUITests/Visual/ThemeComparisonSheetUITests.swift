import XCTest

/// Captures the shared comparison sheet after changes to its text and chart contrast.
@MainActor
final class ThemeComparisonSheetUITests: SeededUITestBaseCase {
    func testEightThemesLightAndDark() {
        let themes = [
            ("desertWarm", "Desert"),
            ("oceanCool", "Ocean"),
            ("forestGreen", "Forest"),
            ("sakuraCalm", "Sakura"),
            ("arcticDawn", "Arctic"),
            ("solarPop", "Solar"),
            ("contourAtlas", "Contour"),
            ("waterLilies", "Water Lilies")
        ]

        for (rawValue, name) in themes {
            for style in ["Light", "Dark"] {
                app.terminate()
                app.launchArguments = launchConfiguration.launchArguments + [
                    "--ui-test-theme", rawValue,
                    "--ui-test-style", style.lowercased(),
                    "-morningBriefingDisabled", "YES"
                ]
                app.launch()
                XCTAssertTrue(app.hasPrimaryNavigation(timeout: 15), "\(name) \(style): primary navigation")
                navigateToWellness()
                XCTAssertTrue(app.waitAndTapToolbarAction("wellness-compare-metrics"), "\(name) \(style): comparison action")
                XCTAssertTrue(app.descendants(matching: .any)["metric-comparison-first"].firstMatch.waitForExistence(timeout: 10))
                addScreenshotAttachment(named: "\(name) \(style) Sheet")
            }
        }
    }
}
