import XCTest

@MainActor
final class WatchSetRPEEntryUITests: WatchUITestBaseCase {
    func testFirstSetCanRateRPEWhenNoEstimateExists() throws {
        startFixtureStrengthWorkout()
        completeOneSetAndReachRestTimer()

        XCTAssertFalse(elementExists(WatchAXID.restTimerRPEBadge, timeout: 1))
        XCTAssertTrue(tapElement(WatchAXID.restTimerRPERate, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.restTimerRPEBadge, timeout: 5))
        XCTAssertTrue(tapElement(WatchAXID.restTimerRPEConfirm, timeout: 5))
        XCTAssertTrue(elementExists(WatchAXID.restTimerScreen, timeout: 5))
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
}
