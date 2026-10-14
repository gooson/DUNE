import XCTest

@MainActor
final class WatchSetRPEEntryUITests: WatchUITestBaseCase {
    func testFirstSetCanRateRPEWhenNoEstimateExists() throws {
        startFixtureStrengthWorkout()
        completeOneSetAndReachRestTimer()

        XCTAssertFalse(elementExists(WatchAXID.restTimerRPEBadge, timeout: 1))
        let addTime = app.buttons["watch-rest-timer-add-time"].firstMatch
        let rateRPE = app.buttons[WatchAXID.restTimerRPERate].firstMatch
        let skip = app.buttons[WatchAXID.restTimerSkipButton].firstMatch
        XCTAssertTrue(addTime.waitForExistence(timeout: 5))
        XCTAssertTrue(rateRPE.waitForExistence(timeout: 5))
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(rateRPE.frame.width, 44)
        XCTAssertGreaterThanOrEqual(rateRPE.frame.minX - addTime.frame.maxX, 3)
        XCTAssertGreaterThanOrEqual(skip.frame.minX - rateRPE.frame.maxX, 3)
        XCTAssertTrue(rateRPE.isHittable)
        // Let the Watch transition finish before saving the actual screen frame.
        sleep(1)
        captureDesignState("S09", visible: WatchAXID.restTimerScreen)
        XCTAssertTrue(tapElement(WatchAXID.restTimerRPERate, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.restTimerRPEConfirm, timeout: 5))
        assertFirstViewportButtons([WatchAXID.restTimerRPEConfirm], screenshot: "rest-rpe-confirm-first-viewport")
        XCTAssertGreaterThanOrEqual(app.buttons[WatchAXID.restTimerRPEConfirm].firstMatch.frame.height, 44)
        captureDesignState("S10", visible: "watch-rest-timer-rpe-sheet")
        XCTAssertTrue(tapElement(WatchAXID.restTimerRPEConfirm, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.restTimerScreen, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.restTimerRPEBadge, timeout: 5))
        captureDesignState("S16", visible: WatchAXID.restTimerScreen)
    }

    func testLastSetRPEConfirmationReturnsToFinishOptions() throws {
        startFixtureStrengthWorkout()

        for setIndex in 1...fixtureStrengthSetCount {
            dismissSetInputSheetIfNeeded()
            XCTAssertTrue(
                tapElement(WatchAXID.sessionMetricsCompleteSetButton, timeout: 5),
                "Complete Set should be available for set \(setIndex)"
            )
            if setIndex < fixtureStrengthSetCount {
                XCTAssertTrue(elementExists(WatchAXID.restTimerScreen, timeout: 5))
                skipRestTimer()
            }
        }

        XCTAssertTrue(tapElement(WatchAXID.lastSetRPEAction, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.lastSetRPESheet, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.lastSetRPEIncrement, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.lastSetRPEDecrement, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.lastSetRPEConfirm, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.sessionMetricsLastSetFinish, timeout: 5))
    }

    func testMissedTargetOffersExplicitLighterWeight() throws {
        startFixtureStrengthWorkout()
        XCTAssertTrue(elementExists(WatchAXID.setInputScreen, timeout: 5))
        XCTAssertTrue(tapElement("watch-set-input-reps-decrement", timeout: 5))
        dismissSetInputSheetIfNeeded()
        XCTAssertTrue(tapElement(WatchAXID.sessionMetricsCompleteSetButton, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.restTimerScreen, timeout: 5))
        skipRestTimer()

        XCTAssertTrue(elementExists(WatchAXID.setInputScreen, timeout: 5))
        XCTAssertTrue(elementExists("watch-set-input-use-lighter-weight", timeout: 5))
        XCTAssertTrue(tapElement("watch-set-input-use-lighter-weight", timeout: 5))
        XCTAssertFalse(elementExists("watch-set-input-use-lighter-weight", timeout: 1))
    }
}
