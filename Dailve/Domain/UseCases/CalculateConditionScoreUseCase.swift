import Foundation

protocol ConditionScoreCalculating: Sendable {
    func execute(input: CalculateConditionScoreUseCase.Input) -> CalculateConditionScoreUseCase.Output
}

struct CalculateConditionScoreUseCase: ConditionScoreCalculating, Sendable {
    let requiredDays = 7

    /// Number of days to include in the condition score baseline window.
    /// Callers should filter HRV samples to this window before passing to execute().
    static let conditionWindowDays = 14

    private let baselineScore = 50.0
    private let zScoreMultiplier = 15.0
    private let minimumStdDev = 0.25
    private let rhrChangeThreshold = 2.0
    private let rhrPenaltyMultiplier = 2.0

    /// Physiological RHR bounds (bpm) — values outside are ignored
    private let rhrValidRange = 20.0...300.0
    /// Physiological HRV bounds (ms) — daily averages outside are excluded
    private let hrvValidRange = 0.0...500.0

    struct Input: Sendable {
        let hrvSamples: [HRVSample]
        let todayRHR: Double?
        let yesterdayRHR: Double?
    }

    struct Output: Sendable {
        let score: ConditionScore?
        let baselineStatus: BaselineStatus
        let contributions: [ScoreContribution]
    }

    func execute(input: Input) -> Output {
        let dailyAverages = computeDailyAverages(from: input.hrvSamples)
        let baselineStatus = BaselineStatus(
            daysCollected: dailyAverages.count,
            daysRequired: requiredDays
        )

        guard baselineStatus.isReady,
              let todayAverage = dailyAverages.first else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }

        // Filter to valid physiological range (0–500ms) and positive values for log()
        let validAverages = dailyAverages.filter { $0.value > 0 && hrvValidRange.contains($0.value) }
        guard !validAverages.isEmpty, todayAverage.value > 0, hrvValidRange.contains(todayAverage.value) else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }

        let lnValues = validAverages.map { log($0.value) }
        let baseline = lnValues.reduce(0, +) / Double(lnValues.count)
        let todayLn = log(todayAverage.value)

        // Coefficient of variation for normal range
        let variance = lnValues.map { ($0 - baseline) * ($0 - baseline) }
            .reduce(0, +) / Double(lnValues.count)

        guard !variance.isNaN && !variance.isInfinite else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }

        let stdDev = sqrt(variance)
        let normalRange = max(stdDev, minimumStdDev)

        let zScore = (todayLn - baseline) / normalRange
        guard !zScore.isNaN && !zScore.isInfinite else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }
        var rawScore = baselineScore + (zScore * zScoreMultiplier)

        // Build contributions with actual numbers
        var contributions: [ScoreContribution] = []
        let baselineHRV = exp(baseline)

        // Guard against exp() overflow for display
        guard !baselineHRV.isNaN && !baselineHRV.isInfinite else {
            return Output(score: nil, baselineStatus: baselineStatus, contributions: [])
        }

        let todayHRVms = todayAverage.value

        let hrvImpact: ScoreContribution.Impact
        let hrvDetail: String
        if zScore > 0.5 {
            hrvImpact = .positive
            hrvDetail = String(format: "%.0fms — above %.0fms avg", todayHRVms, baselineHRV)
        } else if zScore < -0.5 {
            hrvImpact = .negative
            hrvDetail = String(format: "%.0fms — below %.0fms avg", todayHRVms, baselineHRV)
        } else {
            hrvImpact = .neutral
            hrvDetail = String(format: "%.0fms — near %.0fms avg", todayHRVms, baselineHRV)
        }
        contributions.append(ScoreContribution(factor: .hrv, impact: hrvImpact, detail: hrvDetail))

        // RHR correction: rising RHR + falling HRV = stronger fatigue signal
        // Only apply when both values are within physiological range (20–300 bpm)
        var rhrPenalty = 0.0
        if let todayRHR = input.todayRHR, let yesterdayRHR = input.yesterdayRHR,
           rhrValidRange.contains(todayRHR), rhrValidRange.contains(yesterdayRHR) {
            let rhrChange = todayRHR - yesterdayRHR
            if rhrChange > rhrChangeThreshold && zScore < 0 {
                rhrPenalty = rhrChange * rhrPenaltyMultiplier
                rawScore -= rhrPenalty
            } else if rhrChange < -rhrChangeThreshold && zScore > 0 {
                rawScore += abs(rhrChange)
            }

            let rhrImpact: ScoreContribution.Impact
            let rhrDetail: String
            let changeSign = rhrChange >= 0 ? "+" : ""
            if rhrChange < -rhrChangeThreshold {
                rhrImpact = .positive
                rhrDetail = String(format: "%.0f → %.0f bpm (%@%.0f)", yesterdayRHR, todayRHR, changeSign, rhrChange)
            } else if rhrChange > rhrChangeThreshold {
                rhrImpact = .negative
                rhrDetail = String(format: "%.0f → %.0f bpm (%@%.0f)", yesterdayRHR, todayRHR, changeSign, rhrChange)
            } else {
                rhrImpact = .neutral
                rhrDetail = String(format: "%.0f bpm (stable)", todayRHR)
            }
            contributions.append(ScoreContribution(factor: .rhr, impact: rhrImpact, detail: rhrDetail))
        }

        let clampedScore = Int(max(0, min(100, rawScore)).rounded())

        let detail = ConditionScoreDetail(
            todayHRV: todayHRVms,
            baselineHRV: baselineHRV,
            zScore: zScore,
            stdDev: stdDev,
            effectiveStdDev: normalRange,
            daysInBaseline: validAverages.count,
            todayDate: todayAverage.date,
            rawScore: rawScore,
            rhrPenalty: rhrPenalty
        )

        let score = ConditionScore(score: clampedScore, date: Date(), contributions: contributions, detail: detail)

        return Output(score: score, baselineStatus: baselineStatus, contributions: contributions)
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
