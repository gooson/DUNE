import XCTest

@MainActor
final class WatchHomeSmokeTests: WatchUITestBaseCase {
    func testHomeRenders() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        let hasCarousel = elementExists("watch-home-carousel", timeout: 10)
        let hasEmptyState = elementExists("watch-home-empty-state", timeout: 10)
        XCTAssertTrue(hasCarousel || hasEmptyState, "Home should render either carousel or empty state")
    }

    func testNavigateToAllExercises() throws {
        XCTAssertTrue(
            elementExists("watch-home-carousel", timeout: 10) || elementExists("watch-home-empty-state", timeout: 10),
            "Home should be visible before navigation"
        )

        let allExercisesCard = app.descendants(matching: .any)["watch-home-card-all-exercises"].firstMatch
        let browseAllLink = app.descendants(matching: .any)["watch-home-browse-all-link"].firstMatch

        var didTap = false
        if allExercisesCard.waitForExistence(timeout: 2) {
            allExercisesCard.tap()
            didTap = true
        } else {
            for _ in 0 ..< 8 where !didTap {
                app.swipeUp()
                if allExercisesCard.waitForExistence(timeout: 1) {
                    allExercisesCard.tap()
                    didTap = true
                }
            }
        }

        if !didTap, browseAllLink.waitForExistence(timeout: 2) {
            browseAllLink.tap()
            didTap = true
        }

        XCTAssertTrue(didTap, "Should navigate to All Exercises from home")

        let hasQuickstartList = elementExists("watch-quickstart-list", timeout: 8)
        let hasQuickstartEmpty = elementExists("watch-quickstart-empty", timeout: 8)
        XCTAssertTrue(hasQuickstartList || hasQuickstartEmpty, "All Exercises screen should render")
    }
}
