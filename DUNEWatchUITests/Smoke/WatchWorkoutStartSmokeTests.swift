import XCTest

@MainActor
final class WatchWorkoutStartSmokeTests: WatchUITestBaseCase {
    func testStrengthWorkoutCanStartFromQuickStartList() throws {
        startFixtureStrengthWorkout()
    }

    func testStrengthWorkoutShowsInputAndMetricsSurfaces() throws {
        startFixtureStrengthWorkout()
        dismissSetInputSheetIfNeeded()
        XCTAssertTrue(elementExists(WatchAXID.sessionMetricsScreen, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.sessionMetricsCompleteSetButton, timeout: 5))
    }
}
