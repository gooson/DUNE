import Foundation
import Testing
@testable import DUNE

@Suite("Condition score RHR display eligibility")
@MainActor
struct ConditionScoreDisplayTests {
    private let requiredDays = CalculateConditionScoreUseCase().requiredDays

    @Test("An incomplete RHR baseline is unavailable, not a neutral adjustment")
    func incompleteBaselineDoesNotImplyNeutrality() {
        for days in [0, 1, requiredDays - 1] {
            #expect(detail(days: days).rhrAdjustmentForDisplay == nil)
        }
    }

    @Test("An eligible neutral adjustment remains a real zero")
    func completeBaselinePreservesZero() {
        #expect(detail(days: requiredDays).rhrAdjustmentForDisplay == 0)
    }

    @Test("Applied adjustments retain their sign and magnitude")
    func appliedAdjustmentIsNotRecomputed() {
        #expect(detail(days: requiredDays, adjustment: -4.5).rhrAdjustmentForDisplay == -4.5)
        #expect(detail(days: requiredDays, adjustment: 3).rhrAdjustmentForDisplay == 3)
    }

    @Test("Fallback measurements and missing comparison terms cannot imply application")
    func missingComparisonRemainsUnavailable() {
        #expect(detail(days: requiredDays, today: nil).rhrAdjustmentForDisplay == nil)
        #expect(detail(days: requiredDays, baseline: nil).rhrAdjustmentForDisplay == nil)
        #expect(detail(days: requiredDays, delta: nil).rhrAdjustmentForDisplay == nil)
    }

    @Test("A nonempty neutral RHR contribution remains unavailable without an applied baseline")
    func incompleteContributionDoesNotImplyNeutrality() {
        let contribution = ScoreContribution(factor: .rhr, impact: .neutral, detail: "Building baseline")
        for days in [0, 1, requiredDays - 1] {
            #expect(contribution.conditionImpactForDisplay(detail: detail(days: days)) == nil)
        }
        #expect(contribution.conditionImpactForDisplay(detail: detail(days: requiredDays, today: nil)) == nil)
        #expect(contribution.conditionImpactForDisplay(detail: nil) == nil)
    }

    @Test("Eligible RHR impacts and HRV evidence retain the model impact")
    func eligibleContributionRetainsItsImpact() {
        for impact in [ScoreContribution.Impact.positive, .neutral, .negative] {
            let contribution = ScoreContribution(factor: .rhr, impact: impact, detail: "Compared with baseline")
            #expect(contribution.conditionImpactForDisplay(detail: detail(days: requiredDays)) == impact)
        }
        let hrv = ScoreContribution(factor: .hrv, impact: .positive, detail: "Above baseline")
        #expect(hrv.conditionImpactForDisplay(detail: nil) == .positive)
        #expect(hrv.conditionImpactForDisplay(detail: detail(days: 0)) == .positive)
    }

    private func detail(days: Int, adjustment: Double = 0, today: Double? = 54,
                        baseline: Double? = 54, delta: Double? = 0) -> ConditionScoreDetail {
        ConditionScoreDetail(
            todayHRV: 60, baselineHRV: 40, zScore: 2,
            stdDev: 0.2, effectiveStdDev: 0.25, daysInBaseline: 14,
            todayDate: Date(timeIntervalSince1970: 1_793_000_000), rawScore: 80,
            rhrAdjustment: adjustment, todayRHR: today, baselineRHR: baseline,
            rhrDeltaFromBaseline: delta, rhrBaselineDays: days, displayRHR: 54
        )
    }
}
