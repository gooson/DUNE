import XCTest

@MainActor
final class WatchHomeSmokeTests: WatchUITestBaseCase {
    func testHomeRenders() throws {
        ensureHomeVisible()
    }

    func testNavigateToAllExercises() throws {
        openAllExercises()
    }
}
