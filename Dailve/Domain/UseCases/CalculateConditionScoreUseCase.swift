import Foundation

protocol ConditionScoreCalculating: Sendable {
    func execute(input: CalculateConditionScoreUseCase.Input) -> CalculateConditionScoreUseCase.Output
}

struct CalculateConditionScoreUseCase: ConditionScoreCalculating, Sendable {
    let requiredDays = 7

    private let baselineScore = 50.0
    private let zScoreMultiplier = 25.0
    private let minimumStdDev = 0.05
    private let rhrChangeThreshold = 2.0
    private let rhrPenaltyMultiplier = 2.0

    struct Input: Sendable {
        let hrvSamples: [HRVSample]
        let todayRHR: Double?
        let yesterdayRHR: Double?
    }

    struct Output: Sendable {
        let score: ConditionScore?
        let baselineStatus: BaselineStatus
    }

    func execute(input: Input) -> Output {
        let dailyAverages = computeDailyAverages(from: input.hrvSamples)
        let baselineStatus = BaselineStatus(
            daysCollected: dailyAverages.count,
            daysRequired: requiredDays
        )

        guard baselineStatus.isReady,
              let todayAverage = dailyAverages.first else {
            return Output(score: nil, baselineStatus: baselineStatus)
        }

        // Guard against log(0) and invalid values
        let validAverages = dailyAverages.filter { $0.value > 0 }
        guard !validAverages.isEmpty, todayAverage.value > 0 else {
            return Output(score: nil, baselineStatus: baselineStatus)
        }

        let lnValues = validAverages.map { log($0.value) }
        let baseline = lnValues.reduce(0, +) / Double(lnValues.count)
        let todayLn = log(todayAverage.value)

        // Coefficient of variation for normal range
        let variance = lnValues.map { ($0 - baseline) * ($0 - baseline) }
            .reduce(0, +) / Double(lnValues.count)

        guard !variance.isNaN && !variance.isInfinite else {
            return Output(score: nil, baselineStatus: baselineStatus)
        }

        let stdDev = sqrt(variance)
        let normalRange = max(stdDev, minimumStdDev)

        let zScore = (todayLn - baseline) / normalRange
        var rawScore = baselineScore + (zScore * zScoreMultiplier)

        // RHR correction: rising RHR + falling HRV = stronger fatigue signal
        if let todayRHR = input.todayRHR, let yesterdayRHR = input.yesterdayRHR {
            let rhrChange = todayRHR - yesterdayRHR
            if rhrChange > rhrChangeThreshold && zScore < 0 {
                rawScore -= rhrChange * rhrPenaltyMultiplier
            } else if rhrChange < -rhrChangeThreshold && zScore > 0 {
                rawScore += abs(rhrChange)
            }
        }

        let clampedScore = Int(max(0, min(100, rawScore)))
        let score = ConditionScore(score: clampedScore, date: Date())

        return Output(score: score, baselineStatus: baselineStatus)
    }

    // MARK: - Private

    private func computeDailyAverages(from samples: [HRVSample]) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.date)
        }

        return grouped.compactMap { date, samples in
            guard !samples.isEmpty else { return nil }
            let avg = samples.map(\.value).reduce(0, +) / Double(samples.count)
            return (date: date, value: avg)
        }
        .sorted { $0.date > $1.date }
    }
}
