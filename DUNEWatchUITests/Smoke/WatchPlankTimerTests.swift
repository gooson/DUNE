import XCTest

@MainActor
final class WatchPlankTimerTests: WatchUITestBaseCase {
    func testPlankShowsLiveTimer() throws {
        openAllExercises()

        let plankPredicate = NSPredicate(format: "label CONTAINS[c] 'Plank' OR label CONTAINS[c] '플랭크'")
        let plankButton = app.buttons.matching(plankPredicate).firstMatch
        if !plankButton.waitForExistence(timeout: 3) {
            app.swipeUp()
            _ = plankButton.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(plankButton.exists, "Plank should be visible in exercise list")
        plankButton.tap()

        // Workout preview
        XCTAssertTrue(elementExists(WatchAXID.workoutPreviewScreen, timeout: 5))
        addScreenshotAttachment(named: "plank-preview")

        // Start workout
        XCTAssertTrue(tapElement(WatchAXID.workoutPreviewStartButton, timeout: 3))

        let started = waitForAny(
            [WatchAXID.sessionPagingRoot, WatchAXID.setInputScreen, WatchAXID.sessionMetricsScreen, WatchAXID.sessionMetricsCompleteSetButton],
            timeout: 8
        )
        XCTAssertNotNil(started)

        // Dismiss input sheet if shown (for non-duration types)
        dismissSetInputSheetIfNeeded(timeout: 3)

        // Wait 3 seconds for timer to count up
        sleep(3)
        addScreenshotAttachment(named: "plank-timer-running")

        // Complete the set
        XCTAssertTrue(tapElement(WatchAXID.sessionMetricsCompleteSetButton, timeout: 5))

        // Should show rest timer or last set options
        sleep(1)
        addScreenshotAttachment(named: "plank-after-complete")
    }
}
