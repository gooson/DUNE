import XCTest

@MainActor
final class WatchWorkoutStartSmokeTests: WatchUITestBaseCase {
    func testStrengthWorkoutCanStartFromQuickStartList() throws {
        startFixtureStrengthWorkout()
    }
}
