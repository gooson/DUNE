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
            findQuickStartExercise(identifier: WatchAXID.quickStartExerciseSquat),
            "Fixture Squat should be hittable in the All Exercises list"
        )
    }
}
