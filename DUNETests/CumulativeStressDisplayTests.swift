import Foundation
import Testing
@testable import DUNE

@Suite("CumulativeStressDisplay")
@MainActor
struct CumulativeStressDisplayTests {
    @Test("real calculator subsets display effective shares while preserving original weights and score", arguments: [0, 1, 2, 3])
    func supportedSubsets(subset: Int) throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let hrv: [CalculateCumulativeStressUseCase.Input.DailyAverage] = [50.0, 60, 40, 70, 30, 55, 45]
            .enumerated().map { index, value in
                .init(date: date.addingTimeInterval(-Double(index) * 86400), value: value)
            }
        let sleep = SleepRegularityIndex(
            score: 72, bedtimeStdDevMinutes: 25, wakeTimeStdDevMinutes: 20,
            averageBedtime: DateComponents(hour: 23), averageWakeTime: DateComponents(hour: 7),
            dataPointCount: 14, confidence: .high
        )
        let score = try #require(CalculateCumulativeStressUseCase().execute(input: .init(
            hrvDailyAverages: hrv,
            sleepRegularity: subset == 1 || subset == 3 ? sleep : nil,
            weeklyTrainingDurations: subset == 2 || subset == 3
                ? .init(acuteMinutes: 240, chronicWeeklyMinutes: 180) : nil,
            evaluationDate: date
        )))
        let original = score
        let shares = try #require(score.effectiveContributionWeights)
        let displayed = try score.contributions.map { contribution in
            Int((try #require(shares[contribution.id]) * 100).rounded())
        }
        let expectedBase: [[Double]] = [[0.40], [0.40, 0.35], [0.40, 0.25], [0.40, 0.35, 0.25]]
        let expectedDisplayed = [[100], [53, 47], [62, 38], [40, 35, 25]]

        #expect(score.contributions.map(\.weight) == expectedBase[subset])
        #expect(displayed == expectedDisplayed[subset])
        #expect(displayed.reduce(0, +) == 100)
        #expect(abs(shares.values.reduce(0, +) - 1) < 0.000_001)
        let allSharesAreFinite = shares.values.allSatisfy { $0.isFinite }
        #expect(allSharesAreFinite)
        #expect(score == original)
        let weightedRaw = score.contributions.reduce(0) { $0 + $1.rawScore * $1.weight }
        let baseTotal = score.contributions.reduce(0) { $0 + $1.weight }
        #expect(score.score == Int((weightedRaw / baseTotal).rounded()))
    }

    @Test("invalid or unavailable weight sets omit percentages", arguments: [
        [], [0], [0, 0], [-0.1, 0.4], [Double.nan, 0.4],
        [Double.infinity, 0.4], [-Double.infinity],
        [Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude],
    ])
    func unavailableShares(weights: [Double]) {
        let score = makeScore(weights: weights)
        #expect(score.effectiveContributionWeights == nil)
        #expect(score.score == 42)
        #expect(score.contributions.map(\.rawScore) == Array(repeating: 25, count: weights.count))
    }

    @Test("valid zero weight remains a zero share alongside positive weights")
    func zeroWeightIsValid() throws {
        let score = makeScore(weights: [0, 0.4])
        let shares = try #require(score.effectiveContributionWeights)
        #expect(shares[score.contributions[0].id] == 0)
        #expect(shares[score.contributions[1].id] == 1)
        #expect(score.contributions.map(\.weight) == [0, 0.4])
    }

    private func makeScore(weights: [Double]) -> CumulativeStressScore {
        CumulativeStressScore(
            score: 42, level: .moderate,
            contributions: weights.map {
                .init(factor: .hrvVariability, rawScore: 25, weight: $0, detail: "Fixture")
            },
            trend: .stable
        )
    }
}
