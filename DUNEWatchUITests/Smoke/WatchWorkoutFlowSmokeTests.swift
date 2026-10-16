import XCTest

@MainActor
final class WatchWorkoutFlowSmokeTests: WatchUITestBaseCase {
    func testCaptureDiscoveryDesignMap() throws {
        XCTAssertTrue(elementExists(WatchAXID.homeRoot, timeout: 8))
        XCTAssertTrue(tapElement("watch-home-posture-settings"))
        captureDesignState("G01", visible: "watch-posture-settings")
        let postureToggle = app.switches["watch-posture-monitor-toggle"].firstMatch
        XCTAssertTrue(postureToggle.waitForExistence(timeout: 5))
        postureToggle.tap()
        captureDesignState("G02", visible: "watch-posture-reminder-picker")
        app.swipeUp()
        captureDesignState("G03", visible: "watch-posture-today-header")

        launchApp(with: LaunchConfiguration(scenario: .defaultSeeded))
        openAllExercises()
        XCTAssertTrue(elementExists(WatchAXID.quickStartCategoryPicker, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.quickStartCategoryPicker))
        addScreenshotAttachment(named: "watch-design-map-D03")
    }

    func testCaptureEmptyLibraryDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .empty))
        XCTAssertTrue(elementExists(WatchAXID.homeAllExercisesCard, timeout: 8))
        captureDesignState("H04", visible: WatchAXID.homeAllExercisesCard)
        XCTAssertTrue(tapElement(WatchAXID.homeAllExercisesCard))
        captureDesignState("D05", visible: "watch-quickstart-empty-title")
    }

    func testCaptureSearchDesignMap() throws {
        openAllExercises()
        let search = app.textFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        addScreenshotAttachment(named: "watch-design-map-D02")
    }

    func testCaptureNoResultsDesignMap() throws {
        relaunchApp(withAdditionalArguments: ["--ui-watch-no-search-results"])
        openAllExercises()
        app.swipeUp()
        captureDesignState("D04", visible: "watch-quickstart-no-results")
    }

    func testCaptureRepsAndDurationDesignMap() throws {
        openAllExercises()
        guard let crunch = findQuickStartExercise(identifier: WatchAXID.quickStartExerciseCrunch) else {
            XCTFail("Fixture crunch must be reachable")
            return
        }
        crunch.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton))
        captureDesignState("S05", visible: "watch-set-input-reps-increment")
        let toggle = app.switches["watch-set-input-added-weight"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let nestedSwitch = toggle.switches.firstMatch
        (nestedSwitch.exists ? nestedSwitch : toggle).tap()
        captureDesignState("S15", visible: "watch-set-input-weight-increment")
        dismissSetInputSheetIfNeeded()
        captureDesignState("S02", visible: WatchAXID.sessionMetricsScreen)

        launchApp(with: LaunchConfiguration(scenario: .defaultSeeded))
        openAllExercises()
        guard let plank = findQuickStartExercise(identifier: WatchAXID.quickStartExercisePlank) else {
            XCTFail("Fixture plank must be reachable")
            return
        }
        plank.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton))
        captureDesignState("S03", visible: WatchAXID.sessionMetricsScreen)
    }

    func testCaptureEmptyHomeDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .empty,
                                           additionalArguments: ["--ui-watch-home-empty"]))
        captureDesignState("H05", visible: WatchAXID.homeBrowseAllLink)
    }

    func testCaptureSyncFailureDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .empty,
                                           additionalArguments: ["--ui-watch-sync-failed"]))
        XCTAssertTrue(tapElement(WatchAXID.homeAllExercisesCard))
        captureDesignState("D06", visible: "watch-sync-failed")
    }

    func testCaptureDurationInputDesignMap() throws {
        relaunchApp(withAdditionalArguments: ["--ui-watch-duration-input"])
        openAllExercises()
        guard let plank = findQuickStartExercise(identifier: WatchAXID.quickStartExercisePlank) else {
            XCTFail("Fixture plank must be reachable")
            return
        }
        plank.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton))
        captureDesignState("S06", visible: WatchAXID.setInputScreen)
    }

    func testCaptureNextExerciseDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout,
                                           additionalArguments: ["--ui-watch-design-routine"]))
        XCTAssertTrue(tapElement("watch-home-card-routine-00000000-0000-4000-8000-000000000001"))
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton))
        for index in 1...3 {
            dismissSetInputSheetIfNeeded()
            XCTAssertTrue(tapElement(WatchAXID.sessionMetricsCompleteSetButton))
            if index < 3 {
                skipRestTimer()
            }
        }
        XCTAssertTrue(tapElement(WatchAXID.sessionMetricsLastSetFinish))
        captureDesignState("S14", visible: WatchAXID.sessionMetricsNextExercise)
    }

    func testCaptureNowPlayingDesignMap() throws {
        startFixtureStrengthWorkout()
        dismissSetInputSheetIfNeeded()
        XCUIDevice.shared.rotateDigitalCrown(delta: 1.5)
        XCTAssertTrue(elementExists(WatchAXID.sessionPagingRoot, timeout: 5))
        addScreenshotAttachment(named: "watch-design-map-X07")
    }

    func testCaptureCardioNoMovementDesignMap() throws {
        captureCardioPrompt(exerciseID: "running", argument: "--ui-watch-cardio-soft-nudge", code: "C08")
    }

    func testCaptureCardioAutoEndDesignMap() throws {
        captureCardioPrompt(exerciseID: "running", argument: "--ui-watch-cardio-auto-end", code: "C09")
    }

    func testCaptureStairExitDesignMap() throws {
        captureCardioPrompt(exerciseID: "stair-climber", argument: "--ui-watch-cardio-stairs-prompt", code: "C10")
    }

    private func captureCardioPrompt(exerciseID: String, argument: String, code: String) {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout, additionalArguments: [argument]))
        openAllExercises()
        guard let exercise = findQuickStartExercise(identifier: "watch-quickstart-exercise-\(exerciseID)") else {
            XCTFail("Fixture \(exerciseID) must be reachable")
            return
        }
        exercise.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton))
        let expectedTitle: String
        switch code {
        case "C08": expectedTitle = "움직임이 감지되지 않음"
        case "C09": expectedTitle = "운동을 곧 종료할까요?"
        default: expectedTitle = "계단 운동을 마칠까요?"
        }
        XCTAssertTrue(app.staticTexts[expectedTitle].firstMatch.waitForExistence(timeout: 10))
        addScreenshotAttachment(named: "watch-design-map-\(code)")
    }

    func testCaptureSavingDesignMap() throws {
        relaunchApp(withAdditionalArguments: ["--ui-watch-save-delay"])
        completeFixtureStrengthWorkoutToSummary()
        let status = app.staticTexts[WatchAXID.sessionSummarySaveStatus].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertTrue(["Saving...", "저장 중...", "保存中..."].contains(status.label))
        addScreenshotAttachment(named: "watch-design-map-F05")
    }

    func testCaptureSaveErrorDesignMap() throws {
        relaunchApp(withAdditionalArguments: ["--ui-force-session-save-error"])
        completeFixtureStrengthWorkoutToSummary()
        captureDesignState("F06", visible: "watch-session-summary-save-retry-button")
    }

    func testCaptureHomeCardsDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout,
                                           additionalArguments: ["--ui-watch-design-routine"]))
        let routine = "watch-home-card-routine-00000000-0000-4000-8000-000000000001"
        captureDesignState("H01", visible: routine)

        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout))
        let preferred = "watch-home-card-preferred-cycling"
        for _ in 0..<10 where !app.buttons[preferred].firstMatch.isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons[preferred].firstMatch.isHittable)
        captureDesignState("H03", visible: preferred)
    }

    func testCaptureRoutineReorderDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout,
                                           additionalArguments: ["--ui-watch-design-routine", "--ui-watch-strength-start-controls"]))
        XCTAssertTrue(tapElement("watch-home-card-routine-00000000-0000-4000-8000-000000000001"))
        XCTAssertTrue(tapElement("watch-workout-preview-reorder"))
        captureDesignState("P02", visible: "watch-workout-preview-move-down-0")
        XCTAssertTrue(tapElement("watch-workout-preview-reorder"))
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton))
        dismissSetInputSheetIfNeeded()
        openControlsPage()
        XCTAssertTrue(tapElement("watch-session-controls-reorder-button"))
        captureDesignState("X04", visible: "watch-exercise-reorder-screen")
    }

    func testCaptureRoundExerciseDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout))
        openAllExercises()
        guard let circuit = findQuickStartExercise(identifier: "watch-quickstart-exercise-circuit") else {
            XCTFail("Fixture circuit must be reachable")
            return
        }
        circuit.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton))
        dismissSetInputSheetIfNeeded()
        captureDesignState("S17", visible: WatchAXID.sessionMetricsScreen)
    }

    func testCaptureCyclingDetailDesignMap() throws {
        captureCardioDetail(exerciseID: "cycling", code: "C05")
    }

    func testCaptureSwimmingDetailDesignMap() throws {
        captureCardioDetail(exerciseID: "swimming", code: "C06")
    }

    func testCaptureGenericCardioDetailDesignMap() throws {
        captureCardioDetail(exerciseID: "mixedCardio", code: "C07")
    }

    private func captureCardioDetail(exerciseID: String, code: String) {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout))
        openAllExercises()
        guard let exercise = findQuickStartExercise(identifier: "watch-quickstart-exercise-\(exerciseID)") else {
            XCTFail("Fixture \(exerciseID) must be reachable")
            return
        }
        exercise.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton))
        XCTAssertTrue(elementExists("watch-cardio-main-metrics", timeout: 10))
        for _ in 0..<2 { app.swipeLeft() }
        captureDesignState(code, visible: "watch-cardio-secondary")
    }

    func testCaptureRunningDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout))
        openAllExercises()
        guard let running = findQuickStartExercise(identifier: "watch-quickstart-exercise-running") else {
            XCTFail("Fixture running must be reachable")
            return
        }
        running.tap()
        captureDesignState("P03", visible: WatchAXID.workoutPreviewCardioIndoorButton)
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton))
        captureDesignState("C01", visible: "watch-cardio-main-metrics")
        app.swipeLeft()
        captureDesignState("C03", visible: "watch-cardio-hr-zone")
        app.swipeLeft()
        captureDesignState("C04", visible: "watch-cardio-secondary")
        for _ in 0..<3 { app.swipeRight() }
        captureDesignState("X03", visible: WatchAXID.sessionControlsScreen)
        XCTAssertTrue(tapElement(WatchAXID.sessionControlsEndButton))
        let endConfirm = app.buttons.matching(NSPredicate(format: "label IN %@", ["End Workout", "운동 종료", "ワークアウトを終了"])).firstMatch
        XCTAssertTrue(endConfirm.waitForExistence(timeout: 5))
        addScreenshotAttachment(named: "watch-design-map-X05")
        endConfirm.tap()
        if elementExists(WatchAXID.sessionSummaryEffortSheet, timeout: 5) {
            XCTAssertTrue(tapElement(WatchAXID.sessionSummaryEffortDoneButton))
        }
        captureDesignState("F02", visible: WatchAXID.sessionSummaryScreen)
    }

    func testCaptureMachineDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout))
        openAllExercises()
        guard let stair = findQuickStartExercise(identifier: "watch-quickstart-exercise-stair-climber") else {
            XCTFail("Fixture stair climber must be reachable")
            return
        }
        stair.tap()
        captureDesignState("P04", visible: WatchAXID.workoutPreviewLevelValue)
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton))
        captureDesignState("C02", visible: "watch-cardio-main-metrics")
        for _ in 0..<2 { app.swipeLeft() }
        captureDesignState("C11", visible: WatchAXID.cardioLevelValue)
        for _ in 0..<3 { app.swipeRight() }
        captureDesignState("X03", visible: WatchAXID.sessionControlsScreen)
        XCTAssertTrue(tapElement(WatchAXID.sessionControlsEndButton))
        let endConfirm = app.buttons.matching(NSPredicate(format: "label IN %@", ["End Workout", "운동 종료", "ワークアウトを終了"])).firstMatch
        XCTAssertTrue(endConfirm.waitForExistence(timeout: 5))
        endConfirm.tap()
        if elementExists(WatchAXID.sessionSummaryEffortSheet, timeout: 5) {
            XCTAssertTrue(tapElement(WatchAXID.sessionSummaryEffortDoneButton))
        }
        captureDesignState("F07", visible: WatchAXID.sessionSummaryScreen)
    }

    func testCaptureStartErrorDesignMap() throws {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout,
                                           additionalArguments: ["--ui-force-cardio-start-error"]))
        openAllExercises()
        guard let running = findQuickStartExercise(identifier: "watch-quickstart-exercise-running") else {
            XCTFail("Fixture running must be reachable")
            return
        }
        running.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioOutdoorButton))
        captureDesignState("P05", visible: "watch-workout-preview-start-error")
    }

    func testCaptureStrengthControlsDesignMap() throws {
        relaunchApp(withAdditionalArguments: ["--ui-watch-strength-start-controls"])
        startFixtureStrengthWorkout()
        captureDesignState("X01", visible: WatchAXID.sessionControlsScreen)
        XCTAssertTrue(tapElement(WatchAXID.sessionControlsPauseResumeButton))
        captureDesignState("X02", visible: WatchAXID.sessionControlsScreen)
        XCTAssertTrue(tapElement(WatchAXID.sessionControlsEndButton))
        XCTAssertTrue(app.buttons["AX_ActionContentControllerCancelButton"].firstMatch.waitForExistence(timeout: 5))
        addScreenshotAttachment(named: "watch-design-map-X06")
    }

    func testCaptureStrengthDesignMap() throws {
        openAllExercises()
        captureDesignState("D01", visible: WatchAXID.quickStartScreen)
        guard let squat = findQuickStartExercise(identifier: WatchAXID.quickStartExerciseSquat) else {
            XCTFail("Fixture squat must be reachable")
            return
        }
        squat.tap()
        captureDesignState("P01", visible: WatchAXID.workoutPreviewScreen)
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton))
        captureDesignState("S04", visible: WatchAXID.setInputScreen)
        dismissSetInputSheetIfNeeded()
        captureDesignState("S01", visible: WatchAXID.sessionMetricsScreen)
        completeOneSetAndReachRestTimer()
        captureDesignState("S09", visible: WatchAXID.restTimerScreen)
        XCTAssertTrue(tapElement(WatchAXID.restTimerRPERate))
        captureDesignState("S10", visible: "watch-rest-timer-rpe-sheet")
        XCTAssertTrue(tapElement(WatchAXID.restTimerRPEConfirm))
        captureDesignState("S16", visible: WatchAXID.restTimerScreen)
        skipRestTimer()
        if tapElement("watch-set-input-previous-sets-button", timeout: 2) {
            captureDesignState("S08", visible: "watch-set-input-previous-sets-screen")
            XCTAssertTrue(tapElement("watch-set-input-previous-sets-back"))
        }
        dismissSetInputSheetIfNeeded()
        XCTAssertTrue(tapElement(WatchAXID.sessionMetricsCompleteSetButton))
        skipRestTimer()
        dismissSetInputSheetIfNeeded()
        XCTAssertTrue(tapElement(WatchAXID.sessionMetricsCompleteSetButton))
        captureDesignState("S12", visible: WatchAXID.sessionMetricsLastSetFinish)
        XCTAssertTrue(tapElement(WatchAXID.lastSetRPEAction))
        captureDesignState("S13", visible: WatchAXID.lastSetRPESheet)
        XCTAssertTrue(tapElement(WatchAXID.lastSetRPEConfirm))
        XCTAssertTrue(tapElement(WatchAXID.sessionMetricsLastSetFinish))
        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryScreen, timeout: 8))
        if elementExists(WatchAXID.sessionSummaryEffortSheet, timeout: 5) {
            captureDesignState("F04", visible: WatchAXID.sessionSummaryEffortSheet)
            XCTAssertTrue(tapElement(WatchAXID.sessionSummaryEffortDoneButton))
        }
        captureDesignState("F01", visible: WatchAXID.sessionSummaryScreen)
        app.swipeUp()
        captureDesignState("F03", visible: "watch-session-summary-breakdown")
    }

    func testCrunchCanAddAndRemoveWeight() throws {
        openAllExercises()
        guard let crunch = findQuickStartExercise(identifier: WatchAXID.quickStartExerciseCrunch) else {
            XCTFail("Fixture Crunch should be hittable in the All Exercises list")
            return
        }
        crunch.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.setInputScreen, timeout: 10))
        let toggle = app.switches["watch-set-input-added-weight"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let nestedSwitch = toggle.switches.firstMatch
        let switchControl = nestedSwitch.exists ? nestedSwitch : toggle
        XCTAssertFalse(elementExists("watch-set-input-weight-increment", timeout: 1))
        switchControl.tap()
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: toggle)],
                timeout: 5
            ),
            .completed,
            "Added Weight switch should turn on; actual value: \(String(describing: toggle.value))"
        )
        XCTAssertTrue(tapElement("watch-set-input-weight-increment", timeout: 5))
        switchControl.tap()
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: toggle)],
                timeout: 5
            ),
            .completed,
            "Added Weight switch should turn off; actual value: \(String(describing: toggle.value))"
        )
        XCTAssertFalse(elementExists("watch-set-input-weight-increment", timeout: 1))
        XCTAssertTrue(tapElement(WatchAXID.setInputDoneButton, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.sessionMetricsCompleteSetButton, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.restTimerSkipButton, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.setInputScreen, timeout: 5))
        XCTAssertFalse(elementExists("watch-set-input-weight-increment", timeout: 1))
    }

    func testControlsSurfaceIsReachableDuringStrengthWorkout() throws {
        relaunchApp(withAdditionalArguments: ["--ui-watch-strength-start-controls"])
        startFixtureStrengthWorkout()
        openControlsPage()

        XCTAssertTrue(elementExists(WatchAXID.sessionControlsScreen, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.sessionControlsEndButton, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.sessionControlsPauseResumeButton, timeout: 5))
        assertFirstViewportButtons([
            WatchAXID.sessionControlsEndButton,
            WatchAXID.sessionControlsPauseResumeButton
        ], screenshot: "strength-controls")
        for identifier in [WatchAXID.sessionControlsEndButton, WatchAXID.sessionControlsPauseResumeButton] {
            XCTAssertGreaterThanOrEqual(app.buttons[identifier].firstMatch.frame.height, 44,
                                        "\(identifier) should have a practical touch target")
        }
    }

    func testStrengthControlsPauseAndResumeWithoutLeavingWorkout() throws {
        relaunchApp(withAdditionalArguments: ["--ui-watch-strength-start-controls"])
        startFixtureStrengthWorkout()
        openControlsPage()

        let pauseResume = app.buttons[WatchAXID.sessionControlsPauseResumeButton].firstMatch
        XCTAssertTrue(pauseResume.waitForExistence(timeout: 5))
        pauseResume.tap()
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label IN %@", ["Resume", "재개", "再開"]),
                object: pauseResume
            )], timeout: 5),
            .completed,
            "Pause should change the control to Resume"
        )
        pauseResume.tap()
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label IN %@", ["Pause", "일시정지", "一時停止"]),
                object: pauseResume
            )], timeout: 5),
            .completed,
            "Resume should restore the Pause control"
        )
        XCTAssertTrue(elementExists(WatchAXID.sessionControlsScreen, timeout: 5))
    }

    func testRestTimerAppearsAfterCompletingFirstSet() throws {
        startFixtureStrengthWorkout()
        completeOneSetAndReachRestTimer()

        XCTAssertTrue(elementExists(WatchAXID.restTimerScreen, timeout: 5))
        let countdown = app.staticTexts["watch-rest-timer-countdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5), "Remaining rest time should be accessible")
        XCTAssertFalse(countdown.label.isEmpty, "Remaining rest time should have a spoken value")
        XCTAssertTrue(elementExists(WatchAXID.restTimerRPERate, timeout: 5), "RPE entry should remain discoverable")
        assertFirstViewportButtons([
            WatchAXID.restTimerRPERate,
            "watch-rest-timer-add-time",
            WatchAXID.restTimerSkipButton,
            WatchAXID.restTimerEndButton
        ], screenshot: "strength-rest-timer")
        for identifier in [WatchAXID.restTimerRPERate, "watch-rest-timer-add-time", WatchAXID.restTimerSkipButton] {
            XCTAssertGreaterThanOrEqual(app.buttons[identifier].firstMatch.frame.height, 44,
                                        "\(identifier) should have a practical touch target")
        }
    }

    func testRestTimerContinuesAfterCancellingEnd() throws {
        startFixtureStrengthWorkout()
        completeOneSetAndReachRestTimer()
        let countdown = app.staticTexts["watch-rest-timer-countdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        guard let initialSeconds = restSeconds(from: countdown.label) else {
            XCTFail("Countdown should expose minutes and seconds: \(countdown.label)")
            return
        }

        XCTAssertTrue(tapElement(WatchAXID.restTimerEndButton, timeout: 5))
        // watchOS exposes a confirmation dialog's cancel role as its system close button.
        let cancel = app.buttons["AX_ActionContentControllerCancelButton"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "End confirmation should offer cancellation")
        cancel.tap()
        XCTAssertTrue(elementExists(WatchAXID.restTimerScreen, timeout: 5), "Workout should remain active")
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        guard let resumedSeconds = restSeconds(from: countdown.label) else {
            XCTFail("Countdown should still expose minutes and seconds: \(countdown.label)")
            return
        }
        XCTAssertLessThan(resumedSeconds, initialSeconds, "Rest time should advance while confirmation is visible")
        let resumedValue = countdown.label
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "label != %@", resumedValue),
                    object: countdown
                )],
                timeout: 5
            ),
            .completed,
            "Remaining rest time should continue changing after cancellation"
        )
        XCTAssertTrue(app.buttons[WatchAXID.restTimerSkipButton].isHittable)
    }

    func testAddTimeExtendsRemainingRest() throws {
        startFixtureStrengthWorkout()
        completeOneSetAndReachRestTimer()
        let countdown = app.staticTexts["watch-rest-timer-countdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        guard let initialSeconds = restSeconds(from: countdown.label) else {
            XCTFail("Countdown should expose minutes and seconds: \(countdown.label)")
            return
        }

        let addTime = app.buttons["watch-rest-timer-add-time"]
        XCTAssertTrue(addTime.isHittable)
        addTime.tap()
        guard let extendedSeconds = restSeconds(from: countdown.label) else {
            XCTFail("Countdown should remain readable after extending rest: \(countdown.label)")
            return
        }
        XCTAssertGreaterThan(extendedSeconds, initialSeconds, "+30s should extend the running rest timer")
        XCTAssertTrue(app.buttons[WatchAXID.restTimerSkipButton].isHittable)
    }

    func testSingleExerciseWorkoutCanReachSummarySurface() throws {
        completeFixtureStrengthWorkoutToSummary()

        if elementExists(WatchAXID.sessionSummaryEffortSheet, timeout: 3) {
            XCTAssertTrue(tapElement(WatchAXID.sessionSummaryEffortDoneButton, timeout: 5))
        }
        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryScreen, timeout: 8))
        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryEffortButton, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryDoneButton, timeout: 5))
        let duration = app.staticTexts["watch-session-summary-duration-value"].firstMatch
        XCTAssertTrue(duration.waitForExistence(timeout: 5), "Summary should show the duration hero")
        XCTAssertFalse(duration.label.isEmpty, "Summary duration should have an accessible value")
        XCTAssertTrue(duration.isHittable, "Summary duration should be visible before scrolling")
        XCTAssertTrue(elementExists("watch-session-summary-stats", timeout: 5),
                      "Summary should keep the workout statistics below the duration hero")
        XCTAssertGreaterThanOrEqual(app.buttons[WatchAXID.sessionSummaryDoneButton].firstMatch.frame.height, 44,
                                    "Summary Done should have a practical touch target")
        let saveStatus = app.staticTexts[WatchAXID.sessionSummarySaveStatus]
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "label IN %@", ["Saved", "저장됨", "保存済み"]),
                    object: saveStatus
                )],
                timeout: 15
            ),
            .completed,
            "Workout should save while its summary remains open"
        )
        assertFirstViewportButtons([WatchAXID.sessionSummaryDoneButton], screenshot: "strength-summary-done")

        // Leave the summary without tapping Done, as a user who lowers their wrist might.
        app.terminate()
        app.launch()
        XCTAssertTrue(elementExists(WatchAXID.homeRoot, timeout: 10), "Ended workout should not reopen as active")
    }

    func testSummarySaveFailureOffersVisibleRetry() throws {
        relaunchApp(withAdditionalArguments: ["--ui-force-session-save-error"])
        completeFixtureStrengthWorkoutToSummary()

        let retry = app.buttons["watch-session-summary-save-retry-button"].firstMatch
        XCTAssertTrue(retry.waitForExistence(timeout: 8), "A save error should keep Retry visible below summary scrolling")
        XCTAssertTrue(retry.isHittable, "Retry should be reachable without scrolling")
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
        addScreenshotAttachment(named: defaultArtifactName(suffix: "summary-save-error"))

        retry.tap()
        if elementExists(WatchAXID.sessionSummaryEffortSheet, timeout: 5) {
            XCTAssertTrue(tapElement(WatchAXID.sessionSummaryEffortDoneButton, timeout: 5))
        }
        let status = app.staticTexts[WatchAXID.sessionSummarySaveStatus].firstMatch
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label IN %@", ["Saved", "저장됨", "保存済み"]),
                object: status
            )], timeout: 15),
            .completed,
            "Retry should save the workout without leaving the summary"
        )
    }

    private func restSeconds(from label: String) -> Int? {
        let components = label.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]),
              (0..<60).contains(seconds) else {
            return nil
        }
        return minutes * 60 + seconds
    }
}
