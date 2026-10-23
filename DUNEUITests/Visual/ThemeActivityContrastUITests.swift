import XCTest

/// Rechecks the shared activity action fill after its foreground contrast changes.
@MainActor
final class ThemeActivityContrastUITests: SeededUITestBaseCase {
    func testActivityActionAcrossThemes() {
        let themes: [(rawValue: String, name: String)] = [
            ("desertWarm", "Desert"),
            ("oceanCool", "Ocean"),
            ("forestGreen", "Forest"),
            ("sakuraCalm", "Sakura"),
            ("arcticDawn", "Arctic"),
            ("solarPop", "Solar"),
            ("contourAtlas", "Contour"),
            ("waterLilies", "Water Lilies")
        ]
        for theme in themes {
            for style in ["Light", "Dark"] {
                app.terminate()
                app.launchArguments = launchConfiguration.launchArguments + [
                    "--ui-test-theme", theme.rawValue,
                    "--ui-test-style", style.lowercased(),
                    "-morningBriefingDisabled", "YES"
                ]
                app.launch()
                navigateToActivity()
                let button = app.buttons[AXID.activityToolbarAdd].firstMatch
                XCTAssertTrue(button.waitForExistence(timeout: 10), "\(theme.name) \(style): toolbar add")
                XCTAssertTrue(button.isHittable, "\(theme.name) \(style): toolbar add visible")
                addScreenshotAttachment(named: "\(theme.name) \(style) Activity")
            }
        }
    }
}
