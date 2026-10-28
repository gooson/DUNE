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

    func testStairWorkoutContinuesWithoutPromptDesignMap() throws {
        launchApp(with: LaunchConfiguration(
            scenario: .responsiveLayout,
            additionalArguments: ["--ui-watch-home-empty", "--ui-watch-stair-exit-regression"]
        ))
        openAllExercises()
        guard let exercise = findQuickStartExercise(identifier: "watch-quickstart-exercise-stair-climber") else {
            XCTFail("Stair climber fixture must be reachable")
            return
        }
        exercise.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton))

        let elapsed = app.staticTexts["watch-cardio-elapsed-time"].firstMatch
        XCTAssertTrue(elapsed.waitForExistence(timeout: 10))
        let initialTime = elapsed.label
        let initialComponents = initialTime.split(separator: ":").compactMap { Int($0) }
        XCTAssertEqual(initialComponents.count, 2)
        XCTAssertGreaterThanOrEqual(initialComponents[0] * 60 + initialComponents[1], 120)
        let advanced = expectation(for: NSPredicate(format: "label != %@", initialTime), evaluatedWith: elapsed)
        wait(for: [advanced], timeout: 5)
        XCTAssertFalse(app.staticTexts["계단 운동을 마칠까요?"].firstMatch.exists)
        addScreenshotAttachment(named: "watch-design-map-C10")
    }

    func testCardioAlertDoesNotPauseElapsedTime() throws {
        launchApp(with: LaunchConfiguration(
            scenario: .responsiveLayout,
            additionalArguments: ["--ui-watch-home-empty", "--ui-watch-cardio-soft-nudge"]
        ))
        openAllExercises()
        guard let exercise = findQuickStartExercise(identifier: "watch-quickstart-exercise-running") else {
            XCTFail("Running fixture must be reachable")
            return
        }
        exercise.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton))

        let alertTitle = app.staticTexts["움직임이 감지되지 않음"].firstMatch
        XCTAssertTrue(alertTitle.waitForExistence(timeout: 10))
        let shownAt = Date()
        let timePassed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in Date().timeIntervalSince(shownAt) >= 3 },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [timePassed], timeout: 5), .completed)

        XCTAssertTrue(tapElement("계속 운동"))
        let elapsed = app.staticTexts["watch-cardio-elapsed-time"].firstMatch
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        let components = elapsed.label.split(separator: ":").compactMap { Int($0) }
        XCTAssertEqual(components.count, 2)
        XCTAssertGreaterThanOrEqual(components[0] * 60 + components[1], 3)
    }

    func testStairGPSExitReminderKeepsRecordingUntilUserChooses() throws {
        startStairGPSExitFixture()
        let title = app.staticTexts["계단 운동을 마칠까요?"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        addScreenshotAttachment(named: "watch-design-map-C19")

        // The regular inactivity countdown is 10s. This recommendation must outlive it.
        let shownAt = Date()
        let observation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in Date().timeIntervalSince(shownAt) >= 12 },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [observation], timeout: 15), .completed)
        XCTAssertTrue(title.exists)
        XCTAssertTrue(tapElement("계속 운동"))

        let elapsed = app.staticTexts["watch-cardio-elapsed-time"].firstMatch
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        let initialTime = elapsed.label
        let advanced = expectation(for: NSPredicate(format: "label != %@", initialTime), evaluatedWith: elapsed)
        wait(for: [advanced], timeout: 5)
        XCTAssertFalse(title.exists)
        XCTAssertTrue(elementExists("watch-cardio-main-metrics", timeout: 5))
        addScreenshotAttachment(named: "watch-stair-gps-exit-continued")
    }

    func testStairGPSExitReminderEndsOnlyOnExplicitAction() throws {
        startStairGPSExitFixture()
        XCTAssertTrue(app.staticTexts["계단 운동을 마칠까요?"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(tapElement("운동 종료"))
        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryDoneButton, timeout: 10))
        XCTAssertFalse(elementExists("watch-cardio-main-metrics", timeout: 1))
    }

    private func startStairGPSExitFixture() {
        launchApp(with: LaunchConfiguration(
            scenario: .responsiveLayout,
            additionalArguments: ["--ui-watch-home-empty", "--ui-watch-stair-gps-exit"]
        ))
        openAllExercises()
        guard let exercise = findQuickStartExercise(identifier: "watch-quickstart-exercise-stair-climber") else {
            XCTFail("Stair climber fixture must be reachable")
            return
        }
        exercise.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton))
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
        default: XCTFail("Unsupported cardio prompt state: \(code)"); return
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

        launchApp(with: LaunchConfiguration(scenario: .defaultSeeded,
                                           additionalArguments: ["--ui-watch-recent-card"]))
        captureDesignState("H02", visible: "watch-home-card-recent-ui-test-squat")

        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout))
        app.swipeUp()
        let preferredCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "watch-home-card-preferred-")
        )
        let viewport = app.frame
        let preferredCard = preferredCards.allElementsBoundByIndex.first { card in
            viewport.contains(CGPoint(x: card.frame.midX, y: card.frame.midY)) && card.isHittable
        }
        XCTAssertNotNil(preferredCard)
        guard let preferredCard else { return }
        captureDesignState("H03", visible: preferredCard.identifier)
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
        launchApp(with: runningLaunchConfiguration())
        openRunningExerciseList()
        guard let running = findQuickStartExercise(identifier: "watch-quickstart-exercise-running") else {
            XCTFail("Fixture running must be reachable")
            return
        }
        running.tap()
        captureDesignState("P03", visible: WatchAXID.workoutPreviewCardioIndoorButton)
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton))
        XCTAssertTrue(elementExists("watch-running-distance-metrics", timeout: 10))
        app.swipeLeft()
        captureDesignState("C01", visible: "watch-cardio-main-metrics")
        app.swipeLeft()
        captureDesignState("C03", visible: "watch-cardio-hr-zone")
        app.swipeLeft()
        captureDesignState("C04", visible: "watch-cardio-secondary")
        for _ in 0..<4 { app.swipeRight() }
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

    func testRunningDistanceMetricsAndPausedDesignMap() throws {
        startFixtureRunningDistanceWorkout()

        let distance = app.staticTexts["watch-running-distance-value"].firstMatch
        XCTAssertTrue(distance.waitForExistence(timeout: 5))
        let initialDistance = accessibleMetricText(distance)
        XCTAssertTrue(initialDistance.replacingOccurrences(of: ",", with: ".").contains("3.24"),
                      "Seeded running distance should be shown in km")
        for identifier in [
            "watch-running-elapsed-value",
            "watch-running-average-pace-value",
            "watch-running-heart-rate-value"
        ] {
            let metric = app.staticTexts[identifier].firstMatch
            XCTAssertTrue(metric.waitForExistence(timeout: 5), "Missing running metric: \(identifier)")
            let metricText = accessibleMetricText(metric)
            XCTAssertFalse(metricText.isEmpty, "Running metric should have an accessible value: \(identifier)")
            XCTAssertFalse(metricText.contains("--"), "Seeded running metric should have a measurement: \(identifier)")
        }
        XCTAssertTrue(accessibleMetricText(app.staticTexts["watch-running-heart-rate-value"].firstMatch).contains("148"))
        XCTAssertLessThanOrEqual(
            app.staticTexts["watch-running-heart-rate-value"].firstMatch.frame.maxY,
            app.frame.maxY,
            "Heart rate must fit in the default small-Watch viewport"
        )
        captureDesignState("C14", visible: "watch-running-distance-metrics")

        app.swipeLeft()
        XCTAssertTrue(elementExists("watch-cardio-main-metrics", timeout: 5), "Time-first metrics must remain reachable")
        app.swipeRight()
        XCTAssertTrue(elementExists("watch-running-distance-metrics", timeout: 5))
        app.swipeRight()
        XCTAssertTrue(elementExists(WatchAXID.sessionControlsScreen, timeout: 5), "Controls should be one right swipe away")

        let pauseResume = app.buttons[WatchAXID.sessionControlsPauseResumeButton].firstMatch
        XCTAssertTrue(pauseResume.waitForExistence(timeout: 5))
        pauseResume.tap()
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label IN %@", ["Resume", "재개", "再開"]),
                object: pauseResume
            )], timeout: 5),
            .completed
        )
        app.swipeLeft()
        captureDesignState("C15", visible: "watch-running-paused-indicator")
        XCTAssertTrue(elementExists("watch-running-distance-metrics", timeout: 5))
        XCTAssertEqual(accessibleMetricText(app.staticTexts["watch-running-distance-value"].firstMatch), initialDistance)

        app.swipeRight()
        XCTAssertTrue(tapElement(WatchAXID.sessionControlsPauseResumeButton))
        app.swipeLeft()
        XCTAssertTrue(elementExists("watch-running-distance-metrics", timeout: 5))
        XCTAssertFalse(elementExists("watch-running-paused-indicator", timeout: 1))
    }

    func testRunningVoiceFeedbackTogglePersistsAcrossNavigationAndRelaunch() throws {
        startFixtureRunningDistanceWorkout()
        app.swipeRight()

        let voiceToggle = app.switches["watch-running-voice-feedback-toggle"].firstMatch
        XCTAssertTrue(voiceToggle.waitForExistence(timeout: 5))
        if !voiceToggle.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(voiceToggle.isHittable, "Voice Feedback control should be visible on the small Watch")
        captureDesignState("C16", visible: "watch-running-voice-feedback-toggle")
        guard let initialValue = voiceToggle.value as? String else {
            XCTFail("Voice Feedback switch should expose a state")
            return
        }
        voiceToggle.tap()
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value != %@", initialValue),
                object: voiceToggle
            )], timeout: 5),
            .completed,
            "Voice Feedback should change state when tapped"
        )
        guard let changedValue = voiceToggle.value as? String else {
            XCTFail("Changed Voice Feedback switch should expose a state")
            return
        }

        app.swipeLeft()
        XCTAssertTrue(elementExists("watch-running-distance-metrics", timeout: 5))
        app.swipeRight()
        XCTAssertEqual(voiceToggle.value as? String, changedValue)

        launchApp(with: runningLaunchConfiguration(resetState: false))
        if elementExists(WatchAXID.homeRoot, timeout: 3) {
            startRunningWorkoutFromHome()
        }
        if elementExists("watch-running-distance-metrics", timeout: 3) {
            app.swipeRight()
        }
        let restoredToggle = app.switches["watch-running-voice-feedback-toggle"].firstMatch
        XCTAssertTrue(restoredToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredToggle.value as? String, changedValue,
                       "Voice Feedback preference should survive app relaunch")
    }

    func testRunningFeedbackSettingsPersistAcrossSheetAndRelaunch() throws {
        startFixtureRunningDistanceWorkout()
        app.swipeRight()
        openRunningFeedbackSettings()
        captureDesignState("C17", visible: "watch-running-feedback-settings")

        let distancePicker = app.descendants(matching: .any)["watch-running-feedback-distance"].firstMatch
        XCTAssertTrue(distancePicker.waitForExistence(timeout: 5))
        let initialDistance = runningFeedbackPickerText(distancePicker)
        let chosenDistance = initialDistance.contains("2 km") ? "500 m" : "2 km"
        selectRunningFeedbackOption(chosenDistance, in: "watch-running-feedback-distance")
        assertRunningFeedbackPicker(distancePicker, contains: chosenDistance)

        let volume = app.sliders["watch-running-feedback-volume"].firstMatch
        scrollToRunningFeedbackControl(volume)
        XCTAssertTrue(volume.isHittable, "Volume must be adjustable on the small Watch")
        let initialVolume = volume.value as? String
        volume.adjust(toNormalizedSliderPosition: initialVolume?.contains("35") == true ? 0.7 : 0.35)
        guard let chosenVolume = volume.value as? String else {
            XCTFail("Feedback volume should expose its percentage")
            return
        }
        XCTAssertNotEqual(chosenVolume, initialVolume, "Volume adjustment should change the displayed level")

        let paceAlerts = app.switches["watch-running-pace-alerts-toggle"].firstMatch
        scrollToRunningFeedbackControl(paceAlerts)
        XCTAssertTrue(paceAlerts.isHittable)
        if paceAlerts.value as? String != "1" {
            // watchOS exposes the full row as a switch; tap its trailing thumb.
            paceAlerts.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "1"), object: paceAlerts
            )], timeout: 5), .completed,
            "Target pace alerts must be on before checking their settings"
        )
        let target = app.descendants(matching: .any)["watch-running-target-pace-value"].firstMatch
        scrollToRunningFeedbackControl(target)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "Target pace should appear when alerts are enabled")
        let targetPace = runningTargetPaceText(target)
        XCTAssertTrue(targetPace.contains(":"), "Target pace should expose a minutes:seconds value")
        captureDesignState("C18", visible: "watch-running-target-pace-value")

        let tolerancePicker = app.descendants(matching: .any)["watch-running-pace-tolerance"].firstMatch
        scrollToRunningFeedbackControl(tolerancePicker)
        XCTAssertTrue(tolerancePicker.isHittable)
        let initialTolerance = runningFeedbackPickerText(tolerancePicker)
        let chosenTolerance = initialTolerance.contains("30 s") ? "60 s" : "30 s"
        selectRunningFeedbackOption(chosenTolerance, in: "watch-running-pace-tolerance")
        assertRunningFeedbackPicker(tolerancePicker, contains: chosenTolerance)

        XCTAssertTrue(tapElement("watch-running-feedback-settings-done"))
        openRunningFeedbackSettings()
        assertRunningFeedbackSettings(distance: chosenDistance, volume: chosenVolume,
                                      targetPace: targetPace, tolerance: chosenTolerance)
        XCTAssertTrue(tapElement("watch-running-feedback-settings-done"))

        launchApp(with: runningLaunchConfiguration(resetState: false))
        if elementExists(WatchAXID.homeRoot, timeout: 3) {
            startRunningWorkoutFromHome()
        }
        if elementExists("watch-running-distance-metrics", timeout: 3) {
            app.swipeRight()
        }
        openRunningFeedbackSettings()
        assertRunningFeedbackSettings(distance: chosenDistance, volume: chosenVolume,
                                      targetPace: targetPace, tolerance: chosenTolerance)
    }

    private func openRunningFeedbackSettings() {
        let settingsButton = app.buttons["watch-running-feedback-settings-button"].firstMatch
        if !settingsButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsButton.isHittable)
        settingsButton.tap()
        XCTAssertTrue(elementExists("watch-running-feedback-settings", timeout: 5))
    }

    private func scrollToRunningFeedbackControl(_ element: XCUIElement) {
        for _ in 0..<4 where !element.isHittable {
            app.swipeUp()
        }
    }

    private func selectRunningFeedbackOption(_ option: String, in identifier: String) {
        let picker = app.descendants(matching: .any)[identifier].firstMatch
        scrollToRunningFeedbackControl(picker)
        XCTAssertTrue(picker.isHittable, "Picker \(identifier) should be reachable")
        picker.tap()
        let choice = app.buttons[option].firstMatch.waitForExistence(timeout: 3)
            ? app.buttons[option].firstMatch
            : app.staticTexts[option].firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "Missing picker choice: \(option)")
        choice.tap()
    }

    private func assertRunningFeedbackSettings(distance: String, volume: String,
                                               targetPace: String, tolerance: String) {
        let distancePicker = app.descendants(matching: .any)["watch-running-feedback-distance"].firstMatch
        XCTAssertTrue(distancePicker.waitForExistence(timeout: 5))
        assertRunningFeedbackPicker(distancePicker, contains: distance)
        let volumeSlider = app.sliders["watch-running-feedback-volume"].firstMatch
        scrollToRunningFeedbackControl(volumeSlider)
        XCTAssertTrue(volumeSlider.waitForExistence(timeout: 5))
        XCTAssertEqual(volumeSlider.value as? String, volume)
        let target = app.descendants(matching: .any)["watch-running-target-pace-value"].firstMatch
        scrollToRunningFeedbackControl(target)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "Pace alerts should remain enabled")
        XCTAssertEqual(runningTargetPaceText(target), targetPace)
        let tolerancePicker = app.descendants(matching: .any)["watch-running-pace-tolerance"].firstMatch
        scrollToRunningFeedbackControl(tolerancePicker)
        XCTAssertTrue(tolerancePicker.waitForExistence(timeout: 5))
        assertRunningFeedbackPicker(tolerancePicker, contains: tolerance)
    }

    private func runningFeedbackPickerText(_ picker: XCUIElement) -> String {
        ([picker.label, picker.value as? String ?? ""]
            + picker.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: " ")
    }

    private func assertRunningFeedbackPicker(_ picker: XCUIElement, contains value: String) {
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            runningFeedbackPickerText(picker).contains(value)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed,
                       "Expected \(value); picker exposes \(runningFeedbackPickerText(picker))")
    }

    private func runningTargetPaceText(_ target: XCUIElement) -> String {
        let spoken = accessibleMetricText(target)
        if spoken.contains(":") { return spoken }
        let pace = target.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", ":")).firstMatch
        return pace.exists ? pace.label : spoken
    }

    private func startFixtureRunningDistanceWorkout() {
        launchApp(with: runningLaunchConfiguration(seededDistance: true))
        startRunningWorkoutFromHome()
    }

    private func runningLaunchConfiguration(
        resetState: Bool = true,
        seededDistance: Bool = false
    ) -> LaunchConfiguration {
        var arguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if seededDistance { arguments.append("--ui-watch-running-distance") }
        return LaunchConfiguration(resetState: resetState, scenario: .responsiveLayout,
                                   additionalArguments: arguments)
    }

    private func openRunningExerciseList() {
        // Home's outer identifier replaces the carousel identifier in watchOS AX.
        // Lazy cards, including All Exercises, become available after scrolling.
        let home = app.scrollViews[WatchAXID.homeRoot].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 8))
        let allExercises = app.buttons[WatchAXID.homeAllExercisesCard].firstMatch
        for _ in 0..<16 {
            if allExercises.exists && allExercises.isHittable {
                allExercises.tap()
                // The following exercise lookup validates the real list content.
                // Avoid waiting for unrelated, lazily rendered fixture sections.
                XCTAssertTrue(elementExists(WatchAXID.quickStartScreen, timeout: 8))
                return
            }
            home.swipeUp()
        }
        XCTFail("All Exercises must be reachable from the running fixture home")
    }

    private func accessibleMetricText(_ element: XCUIElement) -> String {
        if let value = element.value as? String, !value.isEmpty { return value }
        return element.label
    }

    private func startRunningWorkoutFromHome() {
        openRunningExerciseList()
        guard let running = findQuickStartExercise(identifier: "watch-quickstart-exercise-running") else {
            XCTFail("Fixture running must be reachable")
            return
        }
        running.tap()
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewCardioIndoorButton))
        XCTAssertTrue(elementExists("watch-running-distance-metrics", timeout: 10))
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
