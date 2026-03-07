import XCTest
@testable import DUNEWatch

final class CardioInactivityPolicyTests: XCTestCase {
    func testEvaluateReturnsNoneBeforeSoftThreshold() {
        let now = Date()

        let result = CardioInactivityPolicy.evaluate(
            inactivityDuration: CardioInactivityPolicy.softNudgeAfter - 1,
            autoEndDeadline: nil,
            now: now
        )

        XCTAssertEqual(result, .none)
    }

    func testEvaluateReturnsSoftNudgeBetweenThresholds() {
        let now = Date()

        let result = CardioInactivityPolicy.evaluate(
            inactivityDuration: CardioInactivityPolicy.softNudgeAfter,
            autoEndDeadline: nil,
            now: now
        )

        XCTAssertEqual(result, .softNudge)
    }

    func testEvaluateReturnsConfirmationAtConfirmationThreshold() {
        let now = Date()

        let result = CardioInactivityPolicy.evaluate(
            inactivityDuration: CardioInactivityPolicy.confirmationAfter,
            autoEndDeadline: nil,
            now: now
        )

        guard case .confirmation(let deadline) = result else {
            XCTFail("Expected confirmation state")
            return
        }

        XCTAssertEqual(
            deadline.timeIntervalSince(now),
            CardioInactivityPolicy.countdownDuration,
            accuracy: 0.001
        )
    }

    func testEvaluateRespectsExistingDeadlineUntilAutoEnd() {
        let now = Date()
        let futureDeadline = now.addingTimeInterval(4)

        let beforeDeadline = CardioInactivityPolicy.evaluate(
            inactivityDuration: 999,
            autoEndDeadline: futureDeadline,
            now: now
        )
        XCTAssertEqual(beforeDeadline, .confirmation(deadline: futureDeadline))

        let afterDeadline = CardioInactivityPolicy.evaluate(
            inactivityDuration: 999,
            autoEndDeadline: futureDeadline,
            now: futureDeadline
        )
        XCTAssertEqual(afterDeadline, .autoEnd)
    }
}
