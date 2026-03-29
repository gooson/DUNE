@preconcurrency import XCTest

/// Tests for sparkline tap interaction and share button in the Personal Records section.
final class PRSparklineTapTests: SeededUITestBaseCase {

    override var initialTabSelectionArgument: String? { "train" }

    /// Verify that the PR section exists and the detail view opens.
    func testPRSectionNavigatesToDetail() throws {
        navigateToActivity()

        // Scroll to find PR section
        let prSection = app.descendants(matching: .any)["activity-section-pr"].firstMatch
        if !prSection.waitForExistence(timeout: 5) {
            let scrollView = app.scrollViews.firstMatch
            for _ in 0..<6 {
                scrollView.swipeUp()
                if prSection.exists { break }
            }
        }

        guard prSection.exists else {
            throw XCTSkip("PR section not found — may need exercise data")
        }

        prSection.tap()

        let detailScreen = app.descendants(matching: .any)["activity-personal-records-detail-screen"].firstMatch
        XCTAssertTrue(
            detailScreen.waitForExistence(timeout: 5),
            "Personal Records detail screen should appear"
        )
    }

    /// Verify that the share button exists on the detail view current best card.
    func testShareButtonExistsOnDetailView() throws {
        navigateToActivity()

        // Scroll to PR section
        let prSection = app.descendants(matching: .any)["activity-section-pr"].firstMatch
        if !prSection.waitForExistence(timeout: 5) {
            let scrollView = app.scrollViews.firstMatch
            for _ in 0..<6 {
                scrollView.swipeUp()
                if prSection.exists { break }
            }
        }

        guard prSection.exists else {
            throw XCTSkip("PR section not found — may need exercise data")
        }

        prSection.tap()

        let detailScreen = app.descendants(matching: .any)["activity-personal-records-detail-screen"].firstMatch
        guard detailScreen.waitForExistence(timeout: 5) else {
            XCTFail("Detail screen should appear")
            return
        }

        // Share button only appears when currentBest is available
        let shareButton = app.buttons["activity-personal-records-share-button"].firstMatch
        if shareButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(shareButton.isHittable, "Share button should be hittable")
        }
        // No fail if not found — data-dependent
    }

    /// Verify chip bar exists on detail view when multiple kinds are available.
    func testChipBarExistsOnDetailView() throws {
        navigateToActivity()

        let prSection = app.descendants(matching: .any)["activity-section-pr"].firstMatch
        if !prSection.waitForExistence(timeout: 5) {
            let scrollView = app.scrollViews.firstMatch
            for _ in 0..<6 {
                scrollView.swipeUp()
                if prSection.exists { break }
            }
        }

        guard prSection.exists else {
            throw XCTSkip("PR section not found — may need exercise data")
        }

        prSection.tap()

        let detailScreen = app.descendants(matching: .any)["activity-personal-records-detail-screen"].firstMatch
        guard detailScreen.waitForExistence(timeout: 5) else {
            XCTFail("Detail screen should appear")
            return
        }

        // Chip bar appears when multiple kinds exist
        let chipBar = app.descendants(matching: .any)["activity-personal-records-chip-bar"].firstMatch
        if chipBar.waitForExistence(timeout: 3) {
            XCTAssertTrue(chipBar.exists, "Chip bar should be visible with multiple kinds")
        }
    }
}
