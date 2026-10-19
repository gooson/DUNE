import XCTest

/// Rechecks exercise names and filters after the shared workout picker contrast fix.
@MainActor
final class ThemeWorkoutContrastUITests: SeededUITestBaseCase {
    func testWorkoutPickerAcrossThemes() {
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
                XCTAssertTrue(app.waitAndTap("activity-log-workout-button"), "\(theme.name) \(style): log workout")
                XCTAssertTrue(app.descendants(matching: .any)["picker-root-list"].firstMatch.waitForExistence(timeout: 10))
                let exercise = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "identifier BEGINSWITH %@", "picker-row-"))
                    .firstMatch
                XCTAssertTrue(exercise.waitForExistence(timeout: 10), "\(theme.name) \(style): exercise row")
                addScreenshotAttachment(named: "\(theme.name) \(style) Workout")
            }
        }
    }
}
