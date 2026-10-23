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
        assertTouchTargetsAtLeast44([
            WatchAXID.workoutPreviewLevelDecrease,
            WatchAXID.workoutPreviewLevelIncrease,
            WatchAXID.workoutPreviewCardioIndoorButton
        ])

        let level = app.staticTexts[WatchAXID.workoutPreviewLevelValue].firstMatch
        let initialLevel = level.label
        app.buttons[WatchAXID.workoutPreviewLevelIncrease].tap()
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label != %@", initialLevel),
                object: level
            )], timeout: 5),
            .completed,
            "Preview level control should update its visible value"
        )
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
        assertTouchTargetsAtLeast44([
            WatchAXID.workoutPreviewCardioIndoorButton,
            WatchAXID.workoutPreviewCardioOutdoorButton
        ])
    }

    func testOutdoorStartErrorStillAllowsIndoorRecovery() throws {
        relaunchApp(withAdditionalArguments: ["--ui-force-cardio-start-error"])
        openPreview(for: "running")
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioOutdoorButton, timeout: 5))
        XCTAssertTrue(elementExists("watch-workout-preview-start-error", timeout: 5))
        assertFirstViewportButtons([
            WatchAXID.workoutPreviewCardioIndoorButton,
            WatchAXID.workoutPreviewCardioOutdoorButton
        ], screenshot: "running-start-error")
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.sessionPagingRoot, timeout: 10),
                      "Indoor start should remain available after an outdoor failure")
    }

    func testStrengthPreviewKeepsStartVisible() throws {
        openPreview(for: "ui-test-squat")
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewStrengthList, timeout: 3))
        assertFirstViewportButtons([WatchAXID.workoutPreviewStartButton], screenshot: "strength-preview")
        assertTouchTargetsAtLeast44([WatchAXID.workoutPreviewStartButton])
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
        let level = app.staticTexts[WatchAXID.cardioLevelValue].firstMatch
        let initialLevel = level.label
        app.buttons[WatchAXID.cardioLevelIncrease].tap()
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label != %@", initialLevel),
                object: level
            )], timeout: 5),
            .completed,
            "Active machine level should change during the workout"
        )
        assertFirstViewportButtons([
            WatchAXID.cardioLevelDecrease,
            WatchAXID.cardioLevelIncrease
        ], screenshot: "active-machine-level")
        assertTouchTargetsAtLeast44([WatchAXID.cardioLevelDecrease, WatchAXID.cardioLevelIncrease])
    }

    func testKoreanXXXLCardioBottomMetricsRemainReachable() throws {
        relaunchApp(withAdditionalArguments: [
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"
        ])
        openPreview(for: "running")
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.sessionPagingRoot, timeout: 10))
        XCTAssertTrue(app.staticTexts["달리기"].firstMatch.waitForExistence(timeout: 5),
                      "The cardio activity title should use the Watch Korean catalog")

        let calories = app.staticTexts["kcal"].firstMatch
        XCTAssertTrue(calories.waitForExistence(timeout: 5), "The bottom metric row should render")
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists, "Cardio metrics should offer vertical scrolling")
        for _ in 0..<3 where !calories.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(calories.isHittable, "Calories should be reachable on a small watch at large text sizes")
        addScreenshotAttachment(named: defaultArtifactName(suffix: "korean-xxxl-cardio-bottom"))
    }

    func testKoreanXXXLRestTimerKeepsPrimaryActionsReachable() throws {
        relaunchApp(withAdditionalArguments: [
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"
        ])
        startFixtureStrengthWorkout()
        completeOneSetAndReachRestTimer()

        let countdown = app.staticTexts["watch-rest-timer-countdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        XCTAssertTrue(countdown.isHittable, "Remaining rest time should be visible without scrolling")
        let rpe = app.buttons[WatchAXID.restTimerRPERate]
        XCTAssertTrue(rpe.waitForExistence(timeout: 5), "RPE entry should remain discoverable at large text sizes")
        XCTAssertTrue(rpe.isHittable, "RPE entry should be reachable without scrolling")

        let actions = ["watch-rest-timer-add-time", WatchAXID.restTimerSkipButton]
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<3 where !actions.allSatisfy({ app.buttons[$0].isHittable }) && scrollView.exists {
            scrollView.swipeUp()
        }
        for identifier in actions {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing \(identifier)")
            XCTAssertTrue(button.isHittable, "\(identifier) should be reachable with bounded scrolling")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "\(identifier) should have a practical touch target")
        }
        addScreenshotAttachment(named: defaultArtifactName(suffix: "korean-xxxl-rest-actions"))
    }

    func testKoreanXXXLStrengthControlsKeepPrimaryActionsReachable() throws {
        relaunchApp(withAdditionalArguments: [
            "--ui-watch-strength-start-controls",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"
        ])
        startFixtureStrengthWorkout()
        openControlsPage()

        let actions = [WatchAXID.sessionControlsPauseResumeButton, WatchAXID.sessionControlsEndButton]
        assertFirstViewportButtons(actions, screenshot: "korean-xxxl-strength-controls")
        assertTouchTargetsAtLeast44(actions)
    }

    private func assertTouchTargetsAtLeast44(_ identifiers: [String]) {
        for identifier in identifiers {
            let button = app.buttons[identifier].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing \(identifier)")
            XCTAssertGreaterThanOrEqual(button.frame.width, 44,
                                        "\(identifier) should have a practical touch target width")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44,
                                        "\(identifier) should have a practical touch target height")
        }
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
