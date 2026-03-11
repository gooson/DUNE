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
        XCTAssertTrue(elementExists(WatchAXID.quickStartExerciseSquat, timeout: 5))
    }
}
