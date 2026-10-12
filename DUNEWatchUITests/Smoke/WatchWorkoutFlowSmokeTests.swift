import XCTest

@MainActor
final class WatchWorkoutFlowSmokeTests: WatchUITestBaseCase {
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
