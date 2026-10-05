import XCTest

/// Verifies the first visible watch viewport before any scrolling or Crown input.
@MainActor
final class WatchResponsiveWorkoutLayoutTests: WatchUITestBaseCase {
    override var uiScenario: LaunchScenario? { .responsiveLayout }

    func testStairClimberPreviewKeepsStartAndLevelControlsVisible() throws {
        openPreview(for: "stair-climber")
        assertFirstViewportButtons([
            WatchAXID.workoutPreviewLevelDecrease,
            WatchAXID.workoutPreviewLevelIncrease,
            WatchAXID.workoutPreviewCardioIndoorButton
        ], screenshot: "stair-climber-preview")
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewLevelValue, timeout: 2))
        XCTAssertFalse(app.buttons[WatchAXID.workoutPreviewCardioOutdoorButton].exists)
    }

    func testEllipticalPreviewKeepsStartAndLevelControlsVisible() throws {
        openPreview(for: "elliptical")
        assertFirstViewportButtons([
            WatchAXID.workoutPreviewLevelDecrease,
            WatchAXID.workoutPreviewLevelIncrease,
            WatchAXID.workoutPreviewCardioIndoorButton
        ], screenshot: "elliptical-preview")
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewLevelValue, timeout: 2))
        XCTAssertFalse(app.buttons[WatchAXID.workoutPreviewCardioOutdoorButton].exists)
    }

    func testRunningPreviewKeepsIndoorAndOutdoorStartsVisible() throws {
        openPreview(for: "running")
        assertFirstViewportButtons([
            WatchAXID.workoutPreviewCardioIndoorButton,
            WatchAXID.workoutPreviewCardioOutdoorButton
        ], screenshot: "running-preview")
        XCTAssertFalse(app.buttons[WatchAXID.workoutPreviewLevelIncrease].exists)
    }

    func testStrengthPreviewKeepsStartVisible() throws {
        openPreview(for: "ui-test-squat")
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewStrengthList, timeout: 3))
        assertFirstViewportButtons([WatchAXID.workoutPreviewStartButton], screenshot: "strength-preview")
    }

    func testKoreanXXXLStairClimberKeepsStartVisibleAndLevelReachable() throws {
        relaunchApp(withAdditionalArguments: [
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"
        ])
        openPreview(for: "stair-climber")
        assertFirstViewportButtons([WatchAXID.workoutPreviewCardioIndoorButton], screenshot: "korean-xxxl-stair-preview")

        let decrease = app.buttons[WatchAXID.workoutPreviewLevelDecrease]
        let increase = app.buttons[WatchAXID.workoutPreviewLevelIncrease]
        XCTAssertTrue(decrease.waitForExistence(timeout: 5))
        XCTAssertTrue(increase.waitForExistence(timeout: 5))
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists, "Cardio preview should offer a scroll fallback at large text sizes")
        for _ in 0..<3 where !(decrease.isHittable && increase.isHittable) {
            scrollView.swipeUp()
        }
        XCTAssertTrue(decrease.isHittable, "Decrease level should be reachable with bounded scrolling")
        XCTAssertTrue(increase.isHittable, "Increase level should be reachable with bounded scrolling")
        addScreenshotAttachment(named: defaultArtifactName(suffix: "korean-xxxl-stair-level"))
    }

    func testActiveMachineLevelControlsFitAfterCardioStart() throws {
        openPreview(for: "stair-climber")
        assertFirstViewportButtons([WatchAXID.workoutPreviewCardioIndoorButton], screenshot: "stair-climber-before-start")
        app.buttons[WatchAXID.workoutPreviewCardioIndoorButton].tap()
        XCTAssertTrue(elementExists(WatchAXID.sessionPagingRoot, timeout: 10))

        // Cardio opens on Main Metrics; the secondary page is two left swipes away.
        for _ in 0..<2 { app.swipeLeft() }
        XCTAssertTrue(elementExists(WatchAXID.cardioLevelValue, timeout: 5), "Machine level page should open")
        assertFirstViewportButtons([
            WatchAXID.cardioLevelDecrease,
            WatchAXID.cardioLevelIncrease
        ], screenshot: "active-machine-level")
    }

    private func openPreview(for exerciseID: String) {
        openAllExercises()
        let identifier = "watch-quickstart-exercise-\(exerciseID)"
        guard let exercise = findQuickStartExercise(identifier: identifier, maxSwipes: 8) else {
            XCTFail("Fixture \(exerciseID) should be hittable in All Exercises")
            return
        }
        exercise.tap()
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewScreen, timeout: 5))
    }

}
