import Testing
@testable import DUNEWatch

@Suite("CardioInactivityPolicy")
struct CardioInactivityPolicyTests {
    @Test("Returns none before soft threshold")
    func evaluateReturnsNoneBeforeSoftThreshold() {
        let now = Date()

        let result = CardioInactivityPolicy.evaluate(
            inactivityDuration: CardioInactivityPolicy.softNudgeAfter - 1,
            autoEndDeadline: nil,
            now: now
        )

        #expect(result == .none)
    }

    @Test("Returns softNudge between thresholds")
    func evaluateReturnsSoftNudgeBetweenThresholds() {
        let now = Date()

        let result = CardioInactivityPolicy.evaluate(
            inactivityDuration: CardioInactivityPolicy.softNudgeAfter,
            autoEndDeadline: nil,
            now: now
        )

        #expect(result == .softNudge)
    }

    @Test("Returns confirmation at confirmation threshold")
    func evaluateReturnsConfirmationAtConfirmationThreshold() {
        let now = Date()

        let result = CardioInactivityPolicy.evaluate(
            inactivityDuration: CardioInactivityPolicy.confirmationAfter,
            autoEndDeadline: nil,
            now: now
        )

        guard case .confirmation(let deadline) = result else {
            Issue.record("Expected confirmation state")
            return
        }

        #expect(
            abs(deadline.timeIntervalSince(now) - CardioInactivityPolicy.countdownDuration) < 0.001
        )
    }

    @Test("Respects existing deadline until autoEnd")
    func evaluateRespectsExistingDeadlineUntilAutoEnd() {
        let now = Date()
        let futureDeadline = now.addingTimeInterval(4)

        let beforeDeadline = CardioInactivityPolicy.evaluate(
            inactivityDuration: 999,
            autoEndDeadline: futureDeadline,
            now: now
        )
        #expect(beforeDeadline == .confirmation(deadline: futureDeadline))

        let afterDeadline = CardioInactivityPolicy.evaluate(
            inactivityDuration: 999,
            autoEndDeadline: futureDeadline,
            now: futureDeadline
        )
        #expect(afterDeadline == .autoEnd)
    }
}
