import Foundation
import Testing
@testable import DUNE

@Suite("PredictSleepQualityUseCase")
struct PredictSleepQualityUseCaseTests {
    let sut = PredictSleepQualityUseCase()

    // MARK: - Helpers

    private func makeDefaultInput(
        recentSleepScores: [Int] = [70, 65, 72, 68, 70, 66, 71],
        todayWorkoutIntensity: Double = 0.5,
        hrvTrend: TrendDirection = .stable,
        bedtimeVarianceMinutes: Double = 30,
        conditionScore: Int? = 65,
        dataAvailableDays: Int = 14
    ) -> PredictSleepQualityUseCase.Input {
        .init(
            recentSleepScores: recentSleepScores,
            todayWorkoutIntensity: todayWorkoutIntensity,
            hrvTrend: hrvTrend,
            bedtimeVarianceMinutes: bedtimeVarianceMinutes,
            conditionScore: conditionScore,
            dataAvailableDays: dataAvailableDays
        )
    }

    // MARK: - Basic Output

    @Test("Good conditions produce good/excellent outlook")
    func goodConditions() {
        let result = sut.execute(input: makeDefaultInput(
            recentSleepScores: [80, 75, 78, 82, 76, 80, 79],
            todayWorkoutIntensity: 0.5,
            hrvTrend: .rising,
            bedtimeVarianceMinutes: 20,
            conditionScore: 80
        ))
        #expect(result.predictedScore >= 56)
        #expect(result.outlook == .good || result.outlook == .excellent)
    }

    @Test("Poor conditions produce poor/fair outlook")
    func poorConditions() {
        let result = sut.execute(input: makeDefaultInput(
            recentSleepScores: [30, 25, 35, 28, 32, 20, 30],
            todayWorkoutIntensity: 0.95,
            hrvTrend: .falling,
            bedtimeVarianceMinutes: 120,
            conditionScore: 20
        ))
        #expect(result.predictedScore <= 55)
        #expect(result.outlook == .poor || result.outlook == .fair)
    }

    // MARK: - Outlook Boundaries

    @Test("Score 0-30 → poor outlook")
    func outlookPoor() {
        let prediction = SleepQualityPrediction(predictedScore: 30, confidence: .medium)
        #expect(prediction.outlook == .poor)
    }

    @Test("Score 31-55 → fair outlook")
    func outlookFair() {
        let prediction = SleepQualityPrediction(predictedScore: 31, confidence: .medium)
        #expect(prediction.outlook == .fair)
    }

    @Test("Score 56-75 → good outlook")
    func outlookGood() {
        let prediction = SleepQualityPrediction(predictedScore: 56, confidence: .medium)
        #expect(prediction.outlook == .good)
    }

    @Test("Score 76+ → excellent outlook")
    func outlookExcellent() {
        let prediction = SleepQualityPrediction(predictedScore: 76, confidence: .medium)
        #expect(prediction.outlook == .excellent)
    }

    @Test("Score clamped to 0-100")
    func scoreClamped() {
        let low = SleepQualityPrediction(predictedScore: -10, confidence: .low)
        #expect(low.predictedScore == 0)
        let high = SleepQualityPrediction(predictedScore: 150, confidence: .high)
        #expect(high.predictedScore == 100)
    }

    // MARK: - Confidence Levels

    @Test("Less than 7 days data → low confidence")
    func lowConfidence() {
        let result = sut.execute(input: makeDefaultInput(dataAvailableDays: 3))
        #expect(result.confidence == .low)
    }

    @Test("7-13 days data → medium confidence")
    func mediumConfidence() {
        let result = sut.execute(input: makeDefaultInput(dataAvailableDays: 10))
        #expect(result.confidence == .medium)
    }

    @Test("14+ days data → high confidence")
    func highConfidence() {
        let result = sut.execute(input: makeDefaultInput(dataAvailableDays: 14))
        #expect(result.confidence == .high)
    }

    // MARK: - Workout Effect

    @Test("Moderate workout intensity is positive for sleep")
    func moderateWorkoutPositive() {
        let moderate = sut.execute(input: makeDefaultInput(todayWorkoutIntensity: 0.5))
        let rest = sut.execute(input: makeDefaultInput(todayWorkoutIntensity: 0.0))
        #expect(moderate.predictedScore >= rest.predictedScore)
    }

    @Test("Very intense workout reduces predicted score")
    func intenseWorkoutNegative() {
        let moderate = sut.execute(input: makeDefaultInput(todayWorkoutIntensity: 0.5))
        let intense = sut.execute(input: makeDefaultInput(todayWorkoutIntensity: 1.0))
        #expect(moderate.predictedScore > intense.predictedScore)
    }

    @Test("Intense workout generates tip")
    func intenseWorkoutTip() {
        let result = sut.execute(input: makeDefaultInput(todayWorkoutIntensity: 0.95))
        #expect(!result.tips.isEmpty)
    }

    // MARK: - HRV Trend

    @Test("Rising HRV improves prediction vs falling")
    func hrvTrendEffect() {
        let rising = sut.execute(input: makeDefaultInput(hrvTrend: .rising))
        let falling = sut.execute(input: makeDefaultInput(hrvTrend: .falling))
        #expect(rising.predictedScore > falling.predictedScore)
    }

    // MARK: - Bedtime Consistency

    @Test("Consistent bedtime improves prediction")
    func bedtimeConsistencyEffect() {
        let consistent = sut.execute(input: makeDefaultInput(bedtimeVarianceMinutes: 15))
        let inconsistent = sut.execute(input: makeDefaultInput(bedtimeVarianceMinutes: 100))
        #expect(consistent.predictedScore > inconsistent.predictedScore)
    }

    @Test("High variance generates consistency tip")
    func bedtimeVarianceTip() {
        let result = sut.execute(input: makeDefaultInput(bedtimeVarianceMinutes: 90))
        #expect(result.tips.contains(String(localized: "A consistent bedtime improves sleep quality")))
    }

    // MARK: - Empty Data

    @Test("Empty sleep scores degrade gracefully")
    func emptySleepScores() {
        let result = sut.execute(input: makeDefaultInput(
            recentSleepScores: [],
            dataAvailableDays: 0
        ))
        #expect(result.confidence == .low)
        #expect(result.predictedScore >= 0)
        #expect(result.predictedScore <= 100)
    }

    // MARK: - Factors

    @Test("Factors list includes expected types")
    func factorTypes() {
        let result = sut.execute(input: makeDefaultInput())
        let types = Set(result.factors.map(\.type))
        #expect(types.contains(.workoutEffect))
        #expect(types.contains(.hrvTrend))
        #expect(types.contains(.bedtimeConsistency))
    }

    @Test("Condition factor only present when score provided")
    func conditionFactorPresence() {
        let withCondition = sut.execute(input: makeDefaultInput(conditionScore: 70))
        let withoutCondition = sut.execute(input: makeDefaultInput(conditionScore: nil))
        #expect(withCondition.factors.contains { $0.type == .conditionLevel })
        #expect(!withoutCondition.factors.contains { $0.type == .conditionLevel })
    }
}
