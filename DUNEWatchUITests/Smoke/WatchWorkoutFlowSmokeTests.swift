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
    }

    func testRestTimerAppearsAfterCompletingFirstSet() throws {
        startFixtureStrengthWorkout()
        completeOneSetAndReachRestTimer()

        XCTAssertTrue(elementExists(WatchAXID.restTimerScreen, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.restTimerSkipButton, timeout: 5))
    }

    func testSingleExerciseWorkoutCanReachSummarySurface() throws {
        completeFixtureStrengthWorkoutToSummary()

        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryScreen, timeout: 8))
        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryEffortButton, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.sessionSummaryDoneButton, timeout: 5))
    }
}
