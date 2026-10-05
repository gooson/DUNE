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
            WatchAXID.restTimerSkipButton
        ], screenshot: "strength-rest-timer")
        XCTAssertFalse(app.buttons["watch-rest-timer-end"].exists, "End belongs on Controls during rest")
    }

    func testRestTimerContinuesAfterCancellingEndFromControls() throws {
        startFixtureStrengthWorkout()
        completeOneSetAndReachRestTimer()
        let countdown = app.staticTexts["watch-rest-timer-countdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        guard let initialSeconds = restSeconds(from: countdown.label) else {
            XCTFail("Countdown should expose minutes and seconds: \(countdown.label)")
            return
        }

        openControlsPage()
        XCTAssertTrue(tapElement(WatchAXID.sessionControlsEndButton, timeout: 5))
        let cancel = app.buttons["watch-session-end-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "End confirmation should offer cancellation")
        cancel.tap()
        XCTAssertTrue(elementExists(WatchAXID.sessionControlsScreen, timeout: 5), "Workout should remain active")

        for _ in 0..<4 where !elementExists(WatchAXID.restTimerScreen, timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(elementExists(WatchAXID.restTimerScreen, timeout: 5), "Rest timer should resume after cancellation")
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        guard let resumedSeconds = restSeconds(from: countdown.label) else {
            XCTFail("Countdown should still expose minutes and seconds: \(countdown.label)")
            return
        }
        XCTAssertLessThan(resumedSeconds, initialSeconds, "Rest time should advance while Controls is visible")
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

        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryScreen, timeout: 8))
        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryEffortButton, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryDoneButton, timeout: 5))
        assertFirstViewportButtons([WatchAXID.sessionSummaryDoneButton], screenshot: "strength-summary-done")
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
