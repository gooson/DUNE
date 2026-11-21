import XCTest

@MainActor
final class WatchContourThemeTests: WatchUITestBaseCase {
    override var additionalLaunchArguments: [String] {
        ["--ui-theme", "contourAtlas"]
    }

    func testContourAtlasHomeAndAllExercisesRender() throws {
        ensureHomeVisible()
        addScreenshotAttachment(named: "ContourAtlas-Watch-Home")

        openAllExercises()
        XCTAssertNotNil(
            findQuickStartExercise(identifier: WatchAXID.quickStartExerciseSquat),
            "Contour Atlas All Exercises should show the seeded exercise"
        )
        addScreenshotAttachment(named: "ContourAtlas-Watch-AllExercises")
    }
}
