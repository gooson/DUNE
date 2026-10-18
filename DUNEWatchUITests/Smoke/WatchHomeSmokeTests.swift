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

    func testStartPromptReturnsAfterCarouselScroll() throws {
        launchApp(with: LaunchConfiguration(scenario: .responsiveLayout))

        app.swipeUp()
        let exerciseCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "watch-home-card-preferred-")
        )
        let viewport = app.frame
        let exerciseCard = exerciseCards.allElementsBoundByIndex.first { card in
            viewport.contains(CGPoint(x: card.frame.midX, y: card.frame.midY)) && card.isHittable
        }

        XCTAssertNotNil(exerciseCard, "A preferred exercise should be visible after scrolling")
        guard let exerciseCard else { return }
        XCTAssertTrue(
            WatchAXID.workoutPreviewStartLabels.contains { exerciseCard.label.contains($0) },
            "The Start prompt should reappear when scrolling stops"
        )
        addScreenshotAttachment(named: "watch-design-map-H03")
        exerciseCard.tap()
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewScreen))
    }
}
