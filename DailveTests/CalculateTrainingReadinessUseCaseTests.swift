import Foundation
import Testing
@testable import Dailve

@Suite("CalculateTrainingReadinessUseCase")
struct CalculateTrainingReadinessUseCaseTests {
    let sut = CalculateTrainingReadinessUseCase()
    let calendar = Calendar.current

    // MARK: - Helpers

    private func makeHRVSamples(values: [Double], startingDaysAgo: Int = 0) -> [HRVSample] {
        values.enumerated().map { index, value in
            HRVSample(
                value: value,
                date: calendar.date(byAdding: .day, value: -(startingDaysAgo + index), to: Date()) ?? Date()
            )
        }
    }

    private func makeFatigueState(
        muscle: MuscleGroup = .chest,
        hoursAgo: Double? = nil,
        fatigueRawValue: Int = 5
    ) -> MuscleFatigueState {
        let lastTrained: Date? = hoursAgo.map { Date().addingTimeInterval(-$0 * 3600) }
        let level = FatigueLevel(rawValue: fatigueRawValue) ?? .moderateFatigue
        return MuscleFatigueState(
            muscle: muscle,
            lastTrainedDate: lastTrained,
            hoursSinceLastTrained: hoursAgo,
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
        hrvValues: [Double] = Array(repeating: 50.0, count: 10),
        todayRHR: Double? = 60,
        rhrBaseline: [Double] = Array(repeating: 60.0, count: 10),
        sleepMinutes: Double? = 450,
        deepSleepRatio: Double? = 0.22,
        remSleepRatio: Double? = 0.22,
        fatigueStates: [MuscleFatigueState] = [],
        hrvHistory: [Double] = [50, 52, 48, 51, 49, 53, 50]
    ) -> CalculateTrainingReadinessUseCase.Input {
        .init(
            hrvSamples: makeHRVSamples(values: hrvValues),
            todayRHR: todayRHR,
            rhrBaseline: rhrBaseline,
            sleepDurationMinutes: sleepMinutes,
            deepSleepRatio: deepSleepRatio,
            remSleepRatio: remSleepRatio,
            fatigueStates: fatigueStates,
            hrvHistory: hrvHistory
        )
    }

    // MARK: - Basic Execution

    @Test("Returns valid score with sufficient data")
    func validScore() {
        let result = sut.execute(input: makeDefaultInput())
        #expect(result != nil)
        #expect(result!.score >= 0 && result!.score <= 100)
    }

    @Test("Score is clamped to 0-100")
    func scoreClamped() {
        // Extreme positive: very high HRV today vs low baseline
        let highInput = makeDefaultInput(
            hrvValues: [200] + Array(repeating: 20.0, count: 9),
            todayRHR: 45,
            rhrBaseline: Array(repeating: 70.0, count: 10),
            sleepMinutes: 540,
            deepSleepRatio: 0.30,
            remSleepRatio: 0.30
        )
        let highResult = sut.execute(input: highInput)
        #expect(highResult != nil)
        #expect(highResult!.score >= 0 && highResult!.score <= 100)

        // Extreme negative: very low HRV today vs high baseline
        let lowInput = makeDefaultInput(
            hrvValues: [10] + Array(repeating: 100.0, count: 9),
            todayRHR: 95,
            rhrBaseline: Array(repeating: 55.0, count: 10),
            sleepMinutes: 120,
            deepSleepRatio: 0.05,
            remSleepRatio: 0.05
        )
        let lowResult = sut.execute(input: lowInput)
        #expect(lowResult != nil)
        #expect(lowResult!.score >= 0 && lowResult!.score <= 100)
    }

    // MARK: - Calibrating State

    @Test("isCalibrating true when no HRV samples")
    func calibratingNoSamples() {
        let input = makeDefaultInput(hrvValues: [])
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.isCalibrating)
    }

    @Test("isCalibrating true when fewer than 7 days of HRV data")
    func calibratingInsufficientDays() {
        // 5 samples on same day = only 1 daily average
        let samples = (0..<5).map { i in
            HRVSample(value: 50, date: Date().addingTimeInterval(Double(-i * 60)))
        }
        let input = CalculateTrainingReadinessUseCase.Input(
            hrvSamples: samples,
            todayRHR: 60,
            rhrBaseline: Array(repeating: 60.0, count: 10),
            sleepDurationMinutes: 450,
            deepSleepRatio: 0.22,
            remSleepRatio: 0.22,
            fatigueStates: [],
            hrvHistory: [50, 52, 48]
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.isCalibrating)
    }

    @Test("isCalibrating false with 7+ daily averages")
    func notCalibratingWithSufficientDays() {
        let result = sut.execute(input: makeDefaultInput())
        #expect(result != nil)
        #expect(!result!.isCalibrating)
    }

    // MARK: - Status Thresholds

    @Test("Status matches score thresholds")
    func statusThresholds() {
        let components = TrainingReadiness.Components(
            hrvScore: 50, rhrScore: 50, sleepScore: 50, fatigueScore: 50, trendBonus: 50
        )

        let ready = TrainingReadiness(score: 85, components: components)
        #expect(ready.status == .ready)

        let moderate = TrainingReadiness(score: 70, components: components)
        #expect(moderate.status == .moderate)

        let light = TrainingReadiness(score: 45, components: components)
        #expect(light.status == .light)

        let rest = TrainingReadiness(score: 30, components: components)
        #expect(rest.status == .rest)
    }

    @Test("Status boundary values")
    func statusBoundaries() {
        let c = TrainingReadiness.Components(
            hrvScore: 50, rhrScore: 50, sleepScore: 50, fatigueScore: 50, trendBonus: 50
        )
        #expect(TrainingReadiness(score: 80, components: c).status == .ready)
        #expect(TrainingReadiness(score: 79, components: c).status == .moderate)
        #expect(TrainingReadiness(score: 60, components: c).status == .moderate)
        #expect(TrainingReadiness(score: 59, components: c).status == .light)
        #expect(TrainingReadiness(score: 40, components: c).status == .light)
        #expect(TrainingReadiness(score: 39, components: c).status == .rest)
        #expect(TrainingReadiness(score: 0, components: c).status == .rest)
        #expect(TrainingReadiness(score: 100, components: c).status == .ready)
    }

    // MARK: - HRV Component

    @Test("HRV component neutral with consistent baseline")
    func hrvNeutralBaseline() {
        let input = makeDefaultInput(hrvValues: Array(repeating: 50.0, count: 10))
        let result = sut.execute(input: input)
        #expect(result != nil)
        // Consistent values → z-score ≈ 0 → component ≈ 50
        #expect(result!.components.hrvScore >= 40 && result!.components.hrvScore <= 60)
    }

    @Test("HRV component higher when today is above baseline")
    func hrvHigherAboveBaseline() {
        let input = makeDefaultInput(
            hrvValues: [80] + Array(repeating: 40.0, count: 9)
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.hrvScore > 50)
    }

    @Test("HRV component lower when today is below baseline")
    func hrvLowerBelowBaseline() {
        let input = makeDefaultInput(
            hrvValues: [20] + Array(repeating: 60.0, count: 9)
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.hrvScore < 50)
    }

    @Test("HRV component fallback with zero-value samples")
    func hrvFallbackZeroSamples() {
        let input = makeDefaultInput(hrvValues: Array(repeating: 0.0, count: 10))
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.hrvScore == 50) // Neutral fallback
    }

    // MARK: - RHR Component

    @Test("RHR component higher when RHR below baseline")
    func rhrHigherBelowBaseline() {
        let input = makeDefaultInput(
            todayRHR: 50,
            rhrBaseline: Array(repeating: 65.0, count: 10)
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.rhrScore > 50)
    }

    @Test("RHR component lower when RHR above baseline")
    func rhrLowerAboveBaseline() {
        let input = makeDefaultInput(
            todayRHR: 80,
            rhrBaseline: Array(repeating: 55.0, count: 10)
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.rhrScore < 50)
    }

    @Test("RHR component neutral when no RHR data")
    func rhrNeutralNoData() {
        let input = makeDefaultInput(todayRHR: nil, rhrBaseline: [])
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.rhrScore == 50)
    }

    @Test("RHR rejects out-of-range values")
    func rhrRejectsOutOfRange() {
        let tooLow = makeDefaultInput(todayRHR: 15)
        let tooHigh = makeDefaultInput(todayRHR: 350)
        #expect(sut.execute(input: tooLow)!.components.rhrScore == 50)
        #expect(sut.execute(input: tooHigh)!.components.rhrScore == 50)
    }

    // MARK: - Sleep Component

    @Test("Sleep component high with optimal sleep")
    func sleepHighOptimal() {
        let input = makeDefaultInput(
            sleepMinutes: 480,  // 8 hours
            deepSleepRatio: 0.25,
            remSleepRatio: 0.25
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.sleepScore > 70)
    }

    @Test("Sleep component low with insufficient sleep")
    func sleepLowInsufficient() {
        let input = makeDefaultInput(
            sleepMinutes: 240,  // 4 hours
            deepSleepRatio: 0.08,
            remSleepRatio: 0.08
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.sleepScore < 50)
    }

    @Test("Sleep component neutral when no data")
    func sleepNeutralNoData() {
        let input = makeDefaultInput(sleepMinutes: nil)
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.sleepScore == 50)
    }

    @Test("Sleep rejects out-of-range duration")
    func sleepRejectsOutOfRange() {
        let tooHigh = makeDefaultInput(sleepMinutes: 1500)  // > 1440
        #expect(sut.execute(input: tooHigh)!.components.sleepScore == 50)
    }

    @Test("Sleep rejects invalid deep/rem ratios")
    func sleepRejectsInvalidRatios() {
        let input = makeDefaultInput(
            sleepMinutes: 480,
            deepSleepRatio: 1.5,  // > 1.0
            remSleepRatio: -0.1   // < 0
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        // Invalid ratios should be ignored, only duration counted
        #expect(result!.components.sleepScore > 0)
    }

    // MARK: - Fatigue Component

    @Test("Fatigue component high when fully recovered")
    func fatigueHighRecovered() {
        let states = [
            makeFatigueState(muscle: .chest, hoursAgo: 96, fatigueRawValue: 1),
            makeFatigueState(muscle: .back, hoursAgo: 96, fatigueRawValue: 1),
        ]
        let input = makeDefaultInput(fatigueStates: states)
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.fatigueScore >= 80)
    }

    @Test("Fatigue component low when recently overtrained")
    func fatigueLowOvertrained() {
        let states = [
            makeFatigueState(muscle: .chest, hoursAgo: 2, fatigueRawValue: 9),
            makeFatigueState(muscle: .back, hoursAgo: 3, fatigueRawValue: 8),
        ]
        let input = makeDefaultInput(fatigueStates: states)
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.fatigueScore < 30)
    }

    @Test("Fatigue component defaults to 80 with no states")
    func fatigueDefaultNoStates() {
        let input = makeDefaultInput(fatigueStates: [])
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.fatigueScore == 80)
    }

    @Test("Fatigue recency weighting: older fatigue has less impact")
    func fatigueRecencyWeighting() {
        let recentHigh = [
            makeFatigueState(muscle: .chest, hoursAgo: 12, fatigueRawValue: 8)
        ]
        let oldHigh = [
            makeFatigueState(muscle: .chest, hoursAgo: 80, fatigueRawValue: 8)
        ]
        let recentResult = sut.execute(input: makeDefaultInput(fatigueStates: recentHigh))
        let oldResult = sut.execute(input: makeDefaultInput(fatigueStates: oldHigh))
        #expect(recentResult != nil && oldResult != nil)
        // Recent high fatigue should score lower than old high fatigue
        #expect(recentResult!.components.fatigueScore < oldResult!.components.fatigueScore)
    }

    // MARK: - Trend Component

    @Test("Trend component higher with improving HRV")
    func trendHigherImproving() {
        let input = makeDefaultInput(hrvHistory: [40, 42, 44, 46, 48, 50, 52])
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.trendBonus > 50)
    }

    @Test("Trend component lower with declining HRV")
    func trendLowerDeclining() {
        let input = makeDefaultInput(hrvHistory: [60, 55, 50, 45, 40, 35, 30])
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.trendBonus < 50)
    }

    @Test("Trend component neutral with insufficient data")
    func trendNeutralInsufficient() {
        let input = makeDefaultInput(hrvHistory: [50, 55])  // < 3 points
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.trendBonus == 50)
    }

    // MARK: - NaN / Infinite Defense

    @Test("Returns nil for NaN input values")
    func nanDefense() {
        let input = makeDefaultInput(
            todayRHR: Double.nan,
            sleepMinutes: Double.nan
        )
        let result = sut.execute(input: input)
        // Should still return a result since NaN values get fallback
        #expect(result != nil)
        #expect(result!.components.rhrScore == 50)
        #expect(result!.components.sleepScore == 50)
    }

    @Test("Returns nil for Infinite input values")
    func infiniteDefense() {
        let input = makeDefaultInput(
            todayRHR: Double.infinity,
            sleepMinutes: Double.infinity
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.components.rhrScore == 50)
        #expect(result!.components.sleepScore == 50)
    }

    // MARK: - Weighted Formula Verification

    @Test("Score reflects weighted component sum")
    func weightedFormulaVerification() {
        // All components at neutral (50) → total should be ~50
        let input = makeDefaultInput(
            hrvValues: Array(repeating: 50.0, count: 10),
            todayRHR: nil,
            rhrBaseline: [],
            sleepMinutes: nil,
            fatigueStates: [],
            hrvHistory: []
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        // HRV=50, RHR=50, Sleep=50, Fatigue=80(default), Trend=50
        // Weighted: 50*0.3 + 50*0.2 + 50*0.25 + 80*0.15 + 50*0.1 = 15+10+12.5+12+5 = 54.5
        #expect(result!.score >= 50 && result!.score <= 60)
    }
}
