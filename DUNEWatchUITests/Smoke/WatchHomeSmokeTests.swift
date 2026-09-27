import XCTest

@MainActor
final class WatchHomeSmokeTests: WatchUITestBaseCase {
    func testHomeRenders() throws {
        ensureHomeVisible()
    }

    func testNavigateToAllExercises() throws {
        openAllExercises()
    }

    func testAllExercisesShowsFixtureSurface() throws {
        openAllExercises()
        XCTAssertNotNil(
            findFixtureStrengthExercise(),
            "Fixture Squat should be hittable in the All Exercises list"
        )
    }
}
