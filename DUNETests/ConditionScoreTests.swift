import Foundation
import Testing
@testable import DUNE

@Suite("ConditionScore Model")
struct ConditionScoreTests {

    // MARK: - Helpers

    private static let fixedDate = Date(timeIntervalSinceReferenceDate: 700_000_000)

    private func makeDetail(
        todayHRV: Double = 50,
        baselineHRV: Double = 45,
        rhrPenalty: Double = 0,
        todayRHR: Double? = nil,
        yesterdayRHR: Double? = nil
    ) -> ConditionScoreDetail {
        ConditionScoreDetail(
            todayHRV: todayHRV,
            baselineHRV: baselineHRV,
            zScore: 0.5,
            stdDev: 0.2,
            effectiveStdDev: 0.2,
            daysInBaseline: 14,
            todayDate: Self.fixedDate,
            rawScore: 75,
            rhrPenalty: rhrPenalty,
            todayRHR: todayRHR,
            yesterdayRHR: yesterdayRHR
        )
    }

    // MARK: - Score Clamping

    @Test("Score is clamped between 0 and 100", arguments: [-10, 0, 50, 100, 150])
    func scoreClamping(input: Int) {
        let score = ConditionScore(score: input)
        #expect(score.score >= 0 && score.score <= 100)
    }

    @Test("Status mapping is correct")
    func statusMapping() {
        #expect(ConditionScore(score: 90).status == .excellent)
        #expect(ConditionScore(score: 80).status == .excellent)
        #expect(ConditionScore(score: 79).status == .good)
        #expect(ConditionScore(score: 60).status == .good)
        #expect(ConditionScore(score: 59).status == .fair)
        #expect(ConditionScore(score: 40).status == .fair)
        #expect(ConditionScore(score: 39).status == .tired)
        #expect(ConditionScore(score: 20).status == .tired)
        #expect(ConditionScore(score: 19).status == .warning)
        #expect(ConditionScore(score: 0).status == .warning)
    }

    // MARK: - BaselineStatus

    @Test("BaselineStatus readiness")
    func baselineStatus() {
        let notReady = BaselineStatus(daysCollected: 3, daysRequired: 7)
        #expect(!notReady.isReady)
        #expect(notReady.progress < 1.0)

        let ready = BaselineStatus(daysCollected: 7, daysRequired: 7)
        #expect(ready.isReady)
        #expect(ready.progress == 1.0)
    }

    @Test("BaselineStatus progress is 0 when daysRequired is 0")
    func baselineZeroDaysRequired() {
        let status = BaselineStatus(daysCollected: 5, daysRequired: 0)
        #expect(status.progress == 0)
    }

    // MARK: - narrativeMessage

    @Test("narrativeMessage falls back to guideMessage when detail is nil")
    func narrativeNoDetail() {
        let score = ConditionScore(score: 90, detail: nil)
        #expect(score.narrativeMessage == score.status.guideMessage)
    }

    @Test("narrativeMessage: excellent with detail differs from guideMessage")
    func narrativeExcellentWithDetail() {
        let score = ConditionScore(score: 90, detail: makeDetail(todayHRV: 60, baselineHRV: 50))
        #expect(score.narrativeMessage != score.status.guideMessage)
    }

    @Test("narrativeMessage: excellent HRV above vs below produces different messages")
    func narrativeExcellentBranch() {
        let above = ConditionScore(score: 90, detail: makeDetail(todayHRV: 60, baselineHRV: 50))
        let below = ConditionScore(score: 90, detail: makeDetail(todayHRV: 40, baselineHRV: 50))
        #expect(above.narrativeMessage != below.narrativeMessage)
    }

    @Test("narrativeMessage: good + high rhrPenalty differs from low rhrPenalty")
    func narrativeGoodRHRBranch() {
        let highRHR = ConditionScore(score: 70, detail: makeDetail(rhrPenalty: 10))
        let lowRHR = ConditionScore(score: 70, detail: makeDetail(rhrPenalty: 3))
        #expect(highRHR.narrativeMessage != lowRHR.narrativeMessage)
    }

    @Test("narrativeMessage: fair HRV below vs above produces different messages")
    func narrativeFairBranch() {
        let below = ConditionScore(score: 50, detail: makeDetail(todayHRV: 30, baselineHRV: 50))
        let above = ConditionScore(score: 50, detail: makeDetail(todayHRV: 60, baselineHRV: 50))
        #expect(below.narrativeMessage != above.narrativeMessage)
    }

    @Test("narrativeMessage: tired differs from other statuses")
    func narrativeTired() {
        let tired = ConditionScore(score: 30, detail: makeDetail())
        let excellent = ConditionScore(score: 90, detail: makeDetail())
        #expect(!tired.narrativeMessage.isEmpty)
        #expect(tired.narrativeMessage != tired.status.guideMessage)
        #expect(tired.narrativeMessage != excellent.narrativeMessage)
    }

    @Test("narrativeMessage: warning differs from other statuses")
    func narrativeWarning() {
        let warning = ConditionScore(score: 10, detail: makeDetail())
        let tired = ConditionScore(score: 30, detail: makeDetail())
        #expect(!warning.narrativeMessage.isEmpty)
        #expect(warning.narrativeMessage != warning.status.guideMessage)
        #expect(warning.narrativeMessage != tired.narrativeMessage)
    }

    @Test("narrativeMessage: different statuses produce different messages")
    func narrativeDifferentStatuses() {
        let excellent = ConditionScore(score: 90, detail: makeDetail()).narrativeMessage
        let good = ConditionScore(score: 70, detail: makeDetail()).narrativeMessage
        let fair = ConditionScore(score: 50, detail: makeDetail()).narrativeMessage
        let tired = ConditionScore(score: 30, detail: makeDetail()).narrativeMessage
        let warning = ConditionScore(score: 10, detail: makeDetail()).narrativeMessage
        let messages = Set([excellent, good, fair, tired, warning])
        #expect(messages.count == 5)
    }
}
