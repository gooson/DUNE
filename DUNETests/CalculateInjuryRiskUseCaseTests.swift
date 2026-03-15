import Foundation
import Testing
@testable import DUNE

@Suite("CalculateInjuryRiskUseCase")
struct CalculateInjuryRiskUseCaseTests {
    let sut = CalculateInjuryRiskUseCase()

    // MARK: - Helpers

    private func makeFatigueState(
        muscle: MuscleGroup = .chest,
        fatigueRawValue: Int = 5
    ) -> MuscleFatigueState {
        let level = FatigueLevel(rawValue: fatigueRawValue) ?? .moderateFatigue
        return MuscleFatigueState(
            muscle: muscle,
            lastTrainedDate: Date().addingTimeInterval(-3600),
            hoursSinceLastTrained: 1.0,
            weeklyVolume: 10,
            recoveryPercent: 1.0 - Double(fatigueRawValue) / 10.0,
            compoundScore: CompoundFatigueScore(
                muscle: muscle,
                normalizedScore: Double(fatigueRawValue) / 10.0,
                level: level,
                breakdown: FatigueBreakdown(
                    workoutContributions: [],
                    baseFatigue: Double(fatigueRawValue) / 10.0,
                    sleepModifier: 1.0,
                    readinessModifier: 1.0,
                    effectiveTau: 48.0
                )
            )
        )
    }

    private func makeDefaultInput(
        fatigueStates: [MuscleFatigueState] = [],
        consecutiveTrainingDays: Int = 0,
        currentWeekVolume: Double = 1000,
        previousWeekVolume: Double = 1000,
        sleepDeficitMinutes: Double = 0,
        activeInjuries: [InjuryInfo] = [],
        conditionScore: Int? = 70
    ) -> CalculateInjuryRiskUseCase.Input {
        .init(
            fatigueStates: fatigueStates,
            consecutiveTrainingDays: consecutiveTrainingDays,
            currentWeekVolume: currentWeekVolume,
            previousWeekVolume: previousWeekVolume,
            sleepDeficitMinutes: sleepDeficitMinutes,
            activeInjuries: activeInjuries,
            conditionScore: conditionScore
        )
    }

    private func makeInjury(
        severity: InjurySeverity = .moderate,
        isActive: Bool = true
    ) -> InjuryInfo {
        InjuryInfo(
            id: UUID(),
            bodyPart: .shoulder,
            bodySide: .left,
            severity: severity,
            startDate: Date().addingTimeInterval(-86400 * 3),
            endDate: isActive ? nil : Date(),
            memo: ""
        )
    }

    // MARK: - All Zeros → Low Risk

    @Test("All safe inputs produce score 0")
    func allSafeInputs() {
        let result = sut.execute(input: makeDefaultInput())
        #expect(result.score == 0)
        #expect(result.level == .low)
        #expect(result.factors.isEmpty)
    }

    // MARK: - Level Boundaries

    @Test("Score 25 → low")
    func levelLow() {
        let assessment = InjuryRiskAssessment(score: 25)
        #expect(assessment.level == .low)
    }

    @Test("Score 26 → moderate")
    func levelModerate() {
        let assessment = InjuryRiskAssessment(score: 26)
        #expect(assessment.level == .moderate)
    }

    @Test("Score 50 → moderate")
    func levelModerateUpperBound() {
        let assessment = InjuryRiskAssessment(score: 50)
        #expect(assessment.level == .moderate)
    }

    @Test("Score 51 → high")
    func levelHigh() {
        let assessment = InjuryRiskAssessment(score: 51)
        #expect(assessment.level == .high)
    }

    @Test("Score 75 → high")
    func levelHighUpperBound() {
        let assessment = InjuryRiskAssessment(score: 75)
        #expect(assessment.level == .high)
    }

    @Test("Score 76 → critical")
    func levelCritical() {
        let assessment = InjuryRiskAssessment(score: 76)
        #expect(assessment.level == .critical)
    }

    @Test("Score clamped to 0-100")
    func scoreClamped() {
        let negative = InjuryRiskAssessment(score: -10)
        #expect(negative.score == 0)

        let over = InjuryRiskAssessment(score: 150)
        #expect(over.score == 100)
    }

    // MARK: - Muscle Fatigue Component

    @Test("Overworked muscles increase risk")
    func muscleFatigueRisk() {
        let overworked = [
            makeFatigueState(muscle: .chest, fatigueRawValue: 9),
            makeFatigueState(muscle: .back, fatigueRawValue: 9),
            makeFatigueState(muscle: .shoulders, fatigueRawValue: 3),
        ]
        let result = sut.execute(input: makeDefaultInput(fatigueStates: overworked))
        #expect(result.score > 0)
        #expect(result.factors.contains { $0.type == .muscleFatigue })
    }

    @Test("No fatigue states produces 0 fatigue risk")
    func emptyFatigueStates() {
        let result = sut.execute(input: makeDefaultInput(fatigueStates: []))
        #expect(!result.factors.contains { $0.type == .muscleFatigue })
    }

    // MARK: - Consecutive Training

    @Test("3 or fewer consecutive days → no risk")
    func consecutiveTrainingBelowThreshold() {
        let result = sut.execute(input: makeDefaultInput(consecutiveTrainingDays: 3))
        #expect(!result.factors.contains { $0.type == .consecutiveTraining })
    }

    @Test("7 consecutive days → full consecutive risk")
    func consecutiveTrainingMax() {
        let result = sut.execute(input: makeDefaultInput(consecutiveTrainingDays: 7))
        #expect(result.factors.contains { $0.type == .consecutiveTraining })
        let factor = result.factors.first { $0.type == .consecutiveTraining }
        #expect(factor != nil)
        // Full risk: 1.0 * 0.20 * 100 = 20
        #expect(factor?.contribution == 20)
    }

    @Test("5 consecutive days → partial risk")
    func consecutiveTrainingPartial() {
        let result = sut.execute(input: makeDefaultInput(consecutiveTrainingDays: 5))
        #expect(result.factors.contains { $0.type == .consecutiveTraining })
        let factor = result.factors.first { $0.type == .consecutiveTraining }!
        // (5-3)/(7-3) = 0.5; 0.5 * 0.20 * 100 = 10
        #expect(factor.contribution == 10)
    }

    // MARK: - Volume Spike

    @Test("Same volume → no spike risk")
    func volumeNoSpike() {
        let result = sut.execute(input: makeDefaultInput(
            currentWeekVolume: 1000,
            previousWeekVolume: 1000
        ))
        #expect(!result.factors.contains { $0.type == .volumeSpike })
    }

    @Test("Volume ratio 2.0 → partial spike risk")
    func volumePartialSpike() {
        let result = sut.execute(input: makeDefaultInput(
            currentWeekVolume: 2000,
            previousWeekVolume: 1000
        ))
        #expect(result.factors.contains { $0.type == .volumeSpike })
        let factor = result.factors.first { $0.type == .volumeSpike }!
        // ratio=2.0, excess=0.5, range=1.0 → 0.5 * 0.20 * 100 = 10
        #expect(factor.contribution == 10)
    }

    @Test("Volume ratio 2.5+ → full spike risk")
    func volumeFullSpike() {
        let result = sut.execute(input: makeDefaultInput(
            currentWeekVolume: 3000,
            previousWeekVolume: 1000
        ))
        let factor = result.factors.first { $0.type == .volumeSpike }!
        // ratio=3.0, clamped at 1.0 → 1.0 * 0.20 * 100 = 20
        #expect(factor.contribution == 20)
    }

    @Test("Zero previous volume → no spike risk")
    func volumeZeroPrevious() {
        let result = sut.execute(input: makeDefaultInput(
            currentWeekVolume: 1000,
            previousWeekVolume: 0
        ))
        #expect(!result.factors.contains { $0.type == .volumeSpike })
    }

    // MARK: - Sleep Deficit

    @Test("No sleep deficit → no risk")
    func noSleepDeficit() {
        let result = sut.execute(input: makeDefaultInput(sleepDeficitMinutes: 0))
        #expect(!result.factors.contains { $0.type == .sleepDeficit })
    }

    @Test("60 min deficit → no risk (at threshold)")
    func sleepDeficitAtThreshold() {
        let result = sut.execute(input: makeDefaultInput(sleepDeficitMinutes: 60))
        #expect(!result.factors.contains { $0.type == .sleepDeficit })
    }

    @Test("120 min deficit → partial risk")
    func sleepDeficitPartial() {
        let result = sut.execute(input: makeDefaultInput(sleepDeficitMinutes: 120))
        #expect(result.factors.contains { $0.type == .sleepDeficit })
        let factor = result.factors.first { $0.type == .sleepDeficit }!
        // excess=60, range=120 → 0.5 * 0.15 * 100 = 7
        #expect(factor.contribution == 7)
    }

    @Test("180 min+ deficit → full risk")
    func sleepDeficitFull() {
        let result = sut.execute(input: makeDefaultInput(sleepDeficitMinutes: 240))
        let factor = result.factors.first { $0.type == .sleepDeficit }!
        // clamped 1.0 * 0.15 * 100 = 15
        #expect(factor.contribution == 15)
    }

    // MARK: - Active Injury

    @Test("No injuries → no injury risk")
    func noInjuries() {
        let result = sut.execute(input: makeDefaultInput(activeInjuries: []))
        #expect(!result.factors.contains { $0.type == .activeInjury })
    }

    @Test("Active severe injury → risk present")
    func activeInjuryRisk() {
        let result = sut.execute(input: makeDefaultInput(
            activeInjuries: [makeInjury(severity: .severe, isActive: true)]
        ))
        #expect(result.factors.contains { $0.type == .activeInjury })
        let factor = result.factors.first { $0.type == .activeInjury }!
        // severe riskWeight=1.0, * 0.10 * 100 = 10
        #expect(factor.contribution == 10)
    }

    @Test("Only healed injuries → no injury risk")
    func healedInjuriesNoRisk() {
        let result = sut.execute(input: makeDefaultInput(
            activeInjuries: [makeInjury(severity: .severe, isActive: false)]
        ))
        #expect(!result.factors.contains { $0.type == .activeInjury })
    }

    @Test("Minor active injury → lower contribution")
    func minorInjuryRisk() {
        let result = sut.execute(input: makeDefaultInput(
            activeInjuries: [makeInjury(severity: .minor, isActive: true)]
        ))
        let factor = result.factors.first { $0.type == .activeInjury }!
        // minor riskWeight=0.3, * 0.10 * 100 = 3
        #expect(factor.contribution == 3)
    }

    // MARK: - Low Recovery

    @Test("High condition score → no recovery risk")
    func highConditionNoRisk() {
        let result = sut.execute(input: makeDefaultInput(conditionScore: 70))
        #expect(!result.factors.contains { $0.type == .lowRecovery })
    }

    @Test("Condition 40 → no risk (at boundary)")
    func conditionAtBoundary() {
        let result = sut.execute(input: makeDefaultInput(conditionScore: 40))
        #expect(!result.factors.contains { $0.type == .lowRecovery })
    }

    @Test("Condition 30 → partial recovery risk")
    func lowConditionPartialRisk() {
        let result = sut.execute(input: makeDefaultInput(conditionScore: 30))
        #expect(result.factors.contains { $0.type == .lowRecovery })
        let factor = result.factors.first { $0.type == .lowRecovery }!
        // (40-30)/20 = 0.5, * 0.075 * 100 = 3
        #expect(factor.contribution == 3)
    }

    @Test("Condition 20 or below → full recovery risk")
    func veryLowConditionFullRisk() {
        let result = sut.execute(input: makeDefaultInput(conditionScore: 10))
        let factor = result.factors.first { $0.type == .lowRecovery }!
        // (40-10)/20 = 1.5, clamped 1.0 → 1.0 * 0.075 * 100 = 7
        #expect(factor.contribution == 7)
    }

    @Test("Nil condition score → no recovery risk")
    func nilConditionNoRisk() {
        let result = sut.execute(input: makeDefaultInput(conditionScore: nil))
        #expect(!result.factors.contains { $0.type == .lowRecovery })
    }

    // MARK: - Posture Issue

    @Test("No posture warnings → no posture risk")
    func noPostureWarnings() {
        let input = CalculateInjuryRiskUseCase.Input(
            fatigueStates: [],
            consecutiveTrainingDays: 0,
            currentWeekVolume: 1000,
            previousWeekVolume: 1000,
            sleepDeficitMinutes: 0,
            activeInjuries: [],
            conditionScore: 70,
            postureWarningCount: 0,
            postureScore: 80
        )
        let result = sut.execute(input: input)
        #expect(!result.factors.contains { $0.type == .postureIssue })
    }

    @Test("2 posture warnings → partial posture risk")
    func postureWarningsPartial() {
        let input = CalculateInjuryRiskUseCase.Input(
            fatigueStates: [],
            consecutiveTrainingDays: 0,
            currentWeekVolume: 1000,
            previousWeekVolume: 1000,
            sleepDeficitMinutes: 0,
            activeInjuries: [],
            conditionScore: 70,
            postureWarningCount: 2,
            postureScore: nil
        )
        let result = sut.execute(input: input)
        #expect(result.factors.contains { $0.type == .postureIssue })
        let factor = result.factors.first { $0.type == .postureIssue }!
        // 2 * 0.25 = 0.5, * 0.05 * 100 = 2
        #expect(factor.contribution == 2)
    }

    @Test("4+ posture warnings → full posture risk")
    func postureWarningsFull() {
        let input = CalculateInjuryRiskUseCase.Input(
            fatigueStates: [],
            consecutiveTrainingDays: 0,
            currentWeekVolume: 1000,
            previousWeekVolume: 1000,
            sleepDeficitMinutes: 0,
            activeInjuries: [],
            conditionScore: 70,
            postureWarningCount: 4,
            postureScore: nil
        )
        let result = sut.execute(input: input)
        let factor = result.factors.first { $0.type == .postureIssue }!
        // 4 * 0.25 = 1.0, * 0.05 * 100 = 5
        #expect(factor.contribution == 5)
    }

    @Test("Low posture score contributes to risk")
    func lowPostureScore() {
        let input = CalculateInjuryRiskUseCase.Input(
            fatigueStates: [],
            consecutiveTrainingDays: 0,
            currentWeekVolume: 1000,
            previousWeekVolume: 1000,
            sleepDeficitMinutes: 0,
            activeInjuries: [],
            conditionScore: 70,
            postureWarningCount: 0,
            postureScore: 20
        )
        let result = sut.execute(input: input)
        #expect(result.factors.contains { $0.type == .postureIssue })
        let factor = result.factors.first { $0.type == .postureIssue }!
        // score deficit: (50-20)/50 = 0.6, * 0.05 * 100 = 3
        #expect(factor.contribution == 3)
    }

    @Test("Posture score above 50 with no warnings → no risk")
    func goodPostureNoRisk() {
        let input = CalculateInjuryRiskUseCase.Input(
            fatigueStates: [],
            consecutiveTrainingDays: 0,
            currentWeekVolume: 1000,
            previousWeekVolume: 1000,
            sleepDeficitMinutes: 0,
            activeInjuries: [],
            conditionScore: 70,
            postureWarningCount: 0,
            postureScore: 60
        )
        let result = sut.execute(input: input)
        #expect(!result.factors.contains { $0.type == .postureIssue })
    }

    // MARK: - Combined Scenario

    @Test("Multiple risk factors combine correctly")
    func combinedRisk() {
        let result = sut.execute(input: makeDefaultInput(
            consecutiveTrainingDays: 7,     // full: 20
            currentWeekVolume: 2500,        // full: 20
            previousWeekVolume: 1000,
            sleepDeficitMinutes: 180,       // full: 15
            activeInjuries: [makeInjury(severity: .severe)],  // full: 10
            conditionScore: 10              // full: 10
        ))
        // Without fatigue: 20+20+15+10+7 = 72 (lowRecovery at 7.5%)
        #expect(result.score == 72)
        #expect(result.level == .high)
        #expect(result.factors.count >= 5)
    }
}
