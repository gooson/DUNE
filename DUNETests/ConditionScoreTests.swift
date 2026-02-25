import Foundation
import Testing
@testable import DUNE

@Suite("ConditionScore Model")
struct ConditionScoreTests {
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

    @Test("BaselineStatus readiness")
    func baselineStatus() {
        let notReady = BaselineStatus(daysCollected: 3, daysRequired: 7)
        #expect(!notReady.isReady)
        #expect(notReady.progress < 1.0)

        let ready = BaselineStatus(daysCollected: 7, daysRequired: 7)
        #expect(ready.isReady)
        #expect(ready.progress == 1.0)
    }
}
