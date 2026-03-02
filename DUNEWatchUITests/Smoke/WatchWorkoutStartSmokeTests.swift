import XCTest

@MainActor
final class WatchWorkoutStartSmokeTests: WatchUITestBaseCase {
    func testStrengthWorkoutCanStartFromQuickStartList() throws {
        XCTAssertTrue(
            elementExists("watch-home-carousel", timeout: 10) || elementExists("watch-home-empty-state", timeout: 10),
            "Home should be visible before navigation"
        )

        let allExercisesCard = app.descendants(matching: .any)["watch-home-card-all-exercises"].firstMatch
        let browseAllLink = app.descendants(matching: .any)["watch-home-browse-all-link"].firstMatch

        var didTap = false
        if allExercisesCard.waitForExistence(timeout: 2) {
            allExercisesCard.tap()
            didTap = true
        } else {
            for _ in 0 ..< 8 where !didTap {
                app.swipeUp()
                if allExercisesCard.waitForExistence(timeout: 1) {
                    allExercisesCard.tap()
                    didTap = true
                }
            }
        }

        if !didTap, browseAllLink.waitForExistence(timeout: 2) {
            browseAllLink.tap()
            didTap = true
        }

        XCTAssertTrue(didTap, "Should navigate to All Exercises")
        XCTAssertTrue(elementExists("watch-quickstart-list", timeout: 8), "Quick Start list should render")

        let exercise = app.staticTexts["UI Test Squat"].firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 5), "Fixture exercise should be visible")
        exercise.tap()

        let startButton = app.buttons["Start"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Workout preview should show Start button")
        startButton.tap()

        let started = app.buttons["Complete Set"].firstMatch.waitForExistence(timeout: 8)
            || app.buttons["Done"].firstMatch.waitForExistence(timeout: 8)
        XCTAssertTrue(started, "Workout session should start and show active session UI")

        XCTAssertFalse(
            app.staticTexts["Could not start workout. Please try again."].firstMatch.exists,
            "Start error alert should not be shown"
        )
    }
}
