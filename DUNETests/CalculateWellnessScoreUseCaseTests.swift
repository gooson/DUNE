import Foundation
import Testing
@testable import DUNE

@Suite("CalculateWellnessScoreUseCase")
struct CalculateWellnessScoreUseCaseTests {
    let sut = CalculateWellnessScoreUseCase()
    let referenceDate = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date()

    // MARK: - Normal Cases

    @Test("Full data produces weighted score")
    func fullData() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: 80,
            conditionScore: 70,
            bodyTrend: .init(weightChange: -0.3),
            evaluationDate: referenceDate
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        // Sleep 80*0.35=28, Condition 70*0.30=21, Body ~65*0.20=13 -> ~(28+21+13)/0.85 ≈ 73
        #expect(result!.score >= 60)
        #expect(result!.score <= 90)
        #expect(result!.sleepScore == 80)
        #expect(result!.conditionScore == 70)
        #expect(result!.bodyScore != nil)
    }

    @Test("Full data with posture produces weighted score")
    func fullDataWithPosture() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: 80,
            conditionScore: 70,
            bodyTrend: .init(weightChange: -0.3),
            postureScore: 90,
            evaluationDate: referenceDate
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        // All 4 components: 80*0.35 + 70*0.30 + 65*0.20 + 90*0.15 = 28+21+13+13.5 = 75.5
        #expect(result!.score >= 65)
        #expect(result!.score <= 90)
        #expect(result!.postureScore == 90)
    }

    @Test("Posture only produces valid score")
    func postureOnly() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: nil,
            conditionScore: nil,
            bodyTrend: nil,
            postureScore: 75,
            evaluationDate: referenceDate
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.score == 75)
        #expect(result!.postureScore == 75)
        #expect(result!.sleepScore == nil)
    }

    @Test("Nil posture redistributes weights to other components")
    func nilPostureRedistributes() {
        let withPosture = CalculateWellnessScoreUseCase.Input(
            sleepScore: 80,
            conditionScore: 80,
            bodyTrend: nil,
            postureScore: 80,
            evaluationDate: referenceDate
        )
        let withoutPosture = CalculateWellnessScoreUseCase.Input(
            sleepScore: 80,
            conditionScore: 80,
            bodyTrend: nil,
            evaluationDate: referenceDate
        )
        let resultWith = sut.execute(input: withPosture)
        let resultWithout = sut.execute(input: withoutPosture)
        #expect(resultWith != nil)
        #expect(resultWithout != nil)
        // Both should score ~80 since all components are 80
        #expect(resultWith!.score == resultWithout!.score)
    }

    @Test("Two components redistributes weights")
    func twoComponents() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: 80,
            conditionScore: 60,
            bodyTrend: nil,
            evaluationDate: referenceDate
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        // (80*0.35 + 60*0.30) / (0.35+0.30) = (28+18)/0.65 = 70.77
        #expect(result!.score == 71)
        #expect(result!.bodyScore == nil)
    }

    @Test("Single component uses full weight")
    func singleComponent() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: 85,
            conditionScore: nil,
            bodyTrend: nil,
            evaluationDate: referenceDate
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.score == 85)
    }

    @Test("No components returns nil")
    func noComponents() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: nil,
            conditionScore: nil,
            bodyTrend: nil,
            evaluationDate: referenceDate
        )
        let result = sut.execute(input: input)
        #expect(result == nil)
    }

    // MARK: - Boundary Values

    @Test("Score 100 produces excellent status")
    func excellentBoundary() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: 100,
            conditionScore: nil,
            bodyTrend: nil,
            evaluationDate: referenceDate
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.score == 100)
        #expect(result!.status == .excellent)
    }

    @Test("Score 0 produces warning status")
    func warningBoundary() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: 0,
            conditionScore: nil,
            bodyTrend: nil,
            evaluationDate: referenceDate
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.score == 0)
        #expect(result!.status == .warning)
    }


    @Test("Time-of-day adjustment is applied to wellness score")
    func timeOfDayAdjustmentApplied() {
        let noon = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date()
        let night = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: Date()) ?? Date()

        let noonInput = CalculateWellnessScoreUseCase.Input(
            sleepScore: 80,
            conditionScore: 60,
            bodyTrend: nil,
            evaluationDate: noon
        )
        let nightInput = CalculateWellnessScoreUseCase.Input(
            sleepScore: 80,
            conditionScore: 60,
            bodyTrend: nil,
            evaluationDate: night
        )

        let noonResult = sut.execute(input: noonInput)
        let nightResult = sut.execute(input: nightInput)

        #expect(noonResult != nil)
        #expect(nightResult != nil)
        #expect(nightResult!.score >= noonResult!.score + 5)
        #expect(nightResult!.timeOfDayAdjustment > noonResult!.timeOfDayAdjustment)
    }

    // MARK: - BodyTrend Score

    @Test("Stable weight scores high")
    func stableWeight() {
        let trend = CalculateWellnessScoreUseCase.BodyTrend(
            weightChange: 0.2
        )
        #expect(trend.score >= 65) // stable weight (baseline 50 + 25)
    }

    @Test("Large weight gain scores low")
    func largeWeightGain() {
        let trend = CalculateWellnessScoreUseCase.BodyTrend(
            weightChange: 3.0
        )
        #expect(trend.score <= 40) // gaining weight
    }

    @Test("Weight loss scores moderately")
    func weightLoss() {
        let trend = CalculateWellnessScoreUseCase.BodyTrend(
            weightChange: -1.5
        )
        #expect(trend.score >= 50) // losing weight is positive
    }

    @Test("Nil weight and body fat gives baseline")
    func nilTrend() {
        let trend = CalculateWellnessScoreUseCase.BodyTrend(
            weightChange: nil
        )
        #expect(trend.score == 50) // baseline neutral
    }

    // MARK: - WellnessScore Status Boundaries

    @Test("Status boundaries are correct")
    func statusBoundaries() {
        let cases: [(Int, WellnessScore.Status)] = [
            (100, .excellent), (80, .excellent),
            (79, .good), (60, .good),
            (59, .fair), (40, .fair),
            (39, .tired), (20, .tired),
            (19, .warning), (0, .warning)
        ]
        for (score, expected) in cases {
            let ws = WellnessScore(score: score)
            #expect(ws.status == expected, "Score \(score) should be \(expected), got \(ws.status)")
        }
    }

    @Test("Score is clamped to 0-100")
    func scoreClamping() {
        let overScore = WellnessScore(score: 150)
        #expect(overScore.score == 100)

        let underScore = WellnessScore(score: -20)
        #expect(underScore.score == 0)
    }

    @Test("Guide message is populated")
    func guideMessage() {
        let ws = WellnessScore(score: 85)
        #expect(!ws.guideMessage.isEmpty)
    }
}
