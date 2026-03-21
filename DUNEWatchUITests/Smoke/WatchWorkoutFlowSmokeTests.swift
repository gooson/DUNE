import XCTest

@MainActor
final class WatchWorkoutFlowSmokeTests: WatchUITestBaseCase {
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
