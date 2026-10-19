import XCTest

/// Verifies that every persisted phone theme has a legible Watch entry scene.
@MainActor
final class WatchThemeMatrixUITests: WatchUITestBaseCase {
    func testDesertWorkoutTheme() { captureWorkoutTheme("desertWarm", named: "Desert") }
    func testOceanWorkoutTheme() { captureWorkoutTheme("oceanCool", named: "Ocean") }
    func testForestWorkoutTheme() { captureWorkoutTheme("forestGreen", named: "Forest") }
    func testSakuraWorkoutTheme() { captureWorkoutTheme("sakuraCalm", named: "Sakura") }
    func testArcticWorkoutTheme() { captureWorkoutTheme("arcticDawn", named: "Arctic") }
    func testSolarWorkoutTheme() { captureWorkoutTheme("solarPop", named: "Solar") }
    func testContourWorkoutTheme() { captureWorkoutTheme("contourAtlas", named: "Contour") }
    func testWaterLiliesWorkoutTheme() { captureWorkoutTheme("waterLilies", named: "Water Lilies") }

    func testDesertHomeAndExerciseList() { captureHomeAndExerciseList("desertWarm", named: "Desert") }
    func testOceanHomeAndExerciseList() { captureHomeAndExerciseList("oceanCool", named: "Ocean") }
    func testForestHomeAndExerciseList() { captureHomeAndExerciseList("forestGreen", named: "Forest") }
    func testSakuraHomeAndExerciseList() { captureHomeAndExerciseList("sakuraCalm", named: "Sakura") }
    func testArcticHomeAndExerciseList() { captureHomeAndExerciseList("arcticDawn", named: "Arctic") }
    func testSolarHomeAndExerciseList() { captureHomeAndExerciseList("solarPop", named: "Solar") }
    func testContourHomeAndExerciseList() { captureHomeAndExerciseList("contourAtlas", named: "Contour") }
    func testWaterLiliesHomeAndExerciseList() { captureHomeAndExerciseList("waterLilies", named: "Water Lilies") }

    func testWeightRepsDesignMapCapture() {
        captureDesignMapMetrics(WatchAXID.quickStartExerciseSquat, state: "S01")
    }

    func testRepsOnlyDesignMapCapture() {
        captureDesignMapMetrics(WatchAXID.quickStartExerciseCrunch, state: "S02")
    }

    func testDurationDesignMapCapture() {
        captureDesignMapMetrics(WatchAXID.quickStartExercisePlank, state: "S03")
    }

    private func captureHomeAndExerciseList(_ rawValue: String, named name: String) {
        launchApp(with: LaunchConfiguration(
            scenario: .defaultSeeded,
            additionalArguments: ["--ui-theme", rawValue]
        ))
        ensureHomeVisible()
        XCTAssertTrue(elementExists(WatchAXID.homeAllExercisesCard, timeout: 5))
        addScreenshotAttachment(named: "\(name) Watch Home")

        openAllExercises()
        XCTAssertNotNil(findQuickStartExercise(identifier: WatchAXID.quickStartExerciseSquat))
        addScreenshotAttachment(named: "\(name) Watch All Exercises")
    }

    private func captureWorkoutTheme(_ rawValue: String, named name: String) {
        launchApp(with: LaunchConfiguration(
            scenario: .defaultSeeded,
            additionalArguments: ["--ui-theme", rawValue]
        ))
        ensureHomeVisible()
        openAllExercises()
        guard let squat = findQuickStartExercise(identifier: WatchAXID.quickStartExerciseSquat) else {
            XCTFail("\(name): fixture squat must be reachable")
            return
        }
        squat.tap()
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewScreen, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton))
        dismissSetInputSheetIfNeeded()
        XCTAssertTrue(elementExists(WatchAXID.sessionMetricsScreen, timeout: 8))
        addScreenshotAttachment(named: "\(name) Watch Workout")
    }

    private func captureDesignMapMetrics(_ exerciseIdentifier: String, state: String) {
        launchApp(with: LaunchConfiguration(
            scenario: .defaultSeeded,
            additionalArguments: ["--ui-theme", "desertWarm"]
        ))
        ensureHomeVisible()
        openAllExercises()
        guard let exercise = findQuickStartExercise(identifier: exerciseIdentifier) else {
            XCTFail("\(state): fixture exercise must be reachable")
            return
        }
        exercise.tap()
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewScreen, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton))
        dismissSetInputSheetIfNeeded()
        captureDesignState(state, visible: WatchAXID.sessionMetricsScreen)
    }
}
