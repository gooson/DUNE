import Testing
@testable import Dailve

@Suite("CalculateWellnessScoreUseCase")
struct CalculateWellnessScoreUseCaseTests {
    let sut = CalculateWellnessScoreUseCase()

    // MARK: - Normal Cases

    @Test("Full data produces weighted score")
    func fullData() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: 80,
            conditionScore: 70,
            bodyTrend: .init(weightChange: -0.3)
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        // Sleep 80*0.4=32, Condition 70*0.35=24.5, Body ~75*0.25=18.75 -> ~75
        #expect(result!.score >= 60)
        #expect(result!.score <= 90)
        #expect(result!.sleepScore == 80)
        #expect(result!.conditionScore == 70)
        #expect(result!.bodyScore != nil)
    }

    @Test("Two components redistributes weights")
    func twoComponents() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: 80,
            conditionScore: 60,
            bodyTrend: nil
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        // (80*0.4 + 60*0.35) / (0.4+0.35) = (32+21)/0.75 = 70.67
        #expect(result!.score == 71)
        #expect(result!.bodyScore == nil)
    }

    @Test("Single component uses full weight")
    func singleComponent() {
        let input = CalculateWellnessScoreUseCase.Input(
            sleepScore: 85,
            conditionScore: nil,
            bodyTrend: nil
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
            bodyTrend: nil
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
            bodyTrend: nil
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
            bodyTrend: nil
        )
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.score == 0)
        #expect(result!.status == .warning)
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
