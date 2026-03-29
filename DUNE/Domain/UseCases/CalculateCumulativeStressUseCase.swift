import Foundation

/// Calculates a cumulative stress score from a 30-day window of
/// HRV variability, sleep consistency, and training load data.
struct CalculateCumulativeStressUseCase: Sendable {

    private let hrvWeight = 0.40
    private let sleepWeight = 0.35
    private let activityWeight = 0.25

    /// Minimum days of data required to produce a score.
    static let minimumDays = 7

    struct Input: Sendable {
        let hrvDailyAverages: [DailyAverage]
        let sleepRegularity: SleepRegularityIndex?
        let weeklyTrainingDurations: WeeklyTrainingDurations?
        let evaluationDate: Date

        /// Daily HRV average value for a single day.
        struct DailyAverage: Sendable {
            let date: Date
            let value: Double
        }

        /// Training duration in minutes for the acute and chronic windows.
        struct WeeklyTrainingDurations: Sendable {
            /// Total training minutes in the last 7 days.
            let acuteMinutes: Double
            /// Average weekly training minutes over the last 28 days.
            let chronicWeeklyMinutes: Double
        }

        init(
            hrvDailyAverages: [DailyAverage],
            sleepRegularity: SleepRegularityIndex? = nil,
            weeklyTrainingDurations: WeeklyTrainingDurations? = nil,
            evaluationDate: Date = .now
        ) {
            self.hrvDailyAverages = hrvDailyAverages
            self.sleepRegularity = sleepRegularity
            self.weeklyTrainingDurations = weeklyTrainingDurations
            self.evaluationDate = evaluationDate
        }
    }

    func execute(input: Input) -> CumulativeStressScore? {
        let validHRV = input.hrvDailyAverages.filter { $0.value > 0 && $0.value.isFinite }
        guard validHRV.count >= Self.minimumDays else { return nil }

        // --- HRV Variability (coefficient of variation) ---
        let hrvScore = computeHRVVariabilityScore(from: validHRV)

        // --- Sleep Inconsistency ---
        let sleepScore = computeSleepInconsistencyScore(regularity: input.sleepRegularity)

        // --- Activity Load ---
        let activityScore = computeActivityLoadScore(durations: input.weeklyTrainingDurations)

        // --- Weighted sum ---
        var totalWeight = 0.0
        var weightedSum = 0.0
        var contributions: [CumulativeStressScore.Contribution] = []

        // HRV is always available if we passed the guard
        weightedSum += hrvScore.value * hrvWeight
        totalWeight += hrvWeight
        contributions.append(hrvScore.contribution)

        if let ss = sleepScore {
            weightedSum += ss.value * sleepWeight
            totalWeight += sleepWeight
            contributions.append(ss.contribution)
        }

        if let as_ = activityScore {
            weightedSum += as_.value * activityWeight
            totalWeight += activityWeight
            contributions.append(as_.contribution)
        }

        // Redistribute missing weights proportionally
        let finalScore: Int
        if totalWeight > 0 {
            finalScore = Int(max(0, min(100, (weightedSum / totalWeight))).rounded())
        } else {
            return nil
        }

        // --- Trend ---
        let trend = computeTrend(from: validHRV)

        let level = CumulativeStressScore.Level.from(score: finalScore)

        return CumulativeStressScore(
            score: finalScore,
            level: level,
            contributions: contributions,
            trend: trend,
            date: input.evaluationDate
        )
    }

    // MARK: - HRV Variability

    private struct ScoredContribution {
        let value: Double
        let contribution: CumulativeStressScore.Contribution
    }

    private func computeHRVVariabilityScore(
        from averages: [Input.DailyAverage]
    ) -> ScoredContribution {
        let values = averages.map(\.value)
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else {
            return ScoredContribution(
                value: 50,
                contribution: .init(
                    factor: .hrvVariability,
                    rawScore: 50,
                    weight: hrvWeight,
                    detail: String(localized: "Insufficient HRV data")
                )
            )
        }

        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean // coefficient of variation

        // CV < 0.10 → low stress (~10), CV > 0.30 → high stress (~90)
        // Linear interpolation between these bounds
        let normalized = max(0, min(1, (cv - 0.10) / 0.20))
        let score = normalized * 80 + 10 // Range 10-90

        let detail = String(localized: "HRV variability CV \(String(format: "%.2f", cv))")

        return ScoredContribution(
            value: score,
            contribution: .init(
                factor: .hrvVariability,
                rawScore: score,
                weight: hrvWeight,
                detail: detail
            )
        )
    }

    // MARK: - Sleep Inconsistency

    private func computeSleepInconsistencyScore(
        regularity: SleepRegularityIndex?
    ) -> ScoredContribution? {
        guard let reg = regularity else { return nil }

        // Regularity 100 = perfectly consistent = 0 stress
        // Regularity 0 = completely irregular = 100 stress
        let score = Double(max(0, min(100, 100 - reg.score)))

        let detail: String
        switch reg.score {
        case 80...100:
            detail = String(localized: "Consistent sleep schedule")
        case 60..<80:
            detail = String(localized: "Slightly irregular sleep")
        case 40..<60:
            detail = String(localized: "Irregular sleep schedule")
        default:
            detail = String(localized: "Very irregular sleep")
        }

        return ScoredContribution(
            value: score,
            contribution: .init(
                factor: .sleepConsistency,
                rawScore: score,
                weight: sleepWeight,
                detail: detail
            )
        )
    }

    // MARK: - Activity Load

    private func computeActivityLoadScore(
        durations: Input.WeeklyTrainingDurations?
    ) -> ScoredContribution? {
        guard let d = durations, d.chronicWeeklyMinutes > 0 else { return nil }

        let ratio = d.acuteMinutes / d.chronicWeeklyMinutes

        // Ratio 0.8-1.3 = sweet spot (low stress ≈ 20)
        // Ratio > 1.5 = overload (high stress ≈ 80)
        // Ratio < 0.5 = detraining (moderate stress ≈ 40)
        let score: Double
        let detail: String

        if ratio >= 0.8 && ratio <= 1.3 {
            score = 20
            detail = String(localized: "Training load balanced")
        } else if ratio > 1.3 {
            let excess = min(1, (ratio - 1.3) / 0.5) // 1.3→1.8 maps to 0→1
            score = 20 + excess * 60 // 20→80
            detail = String(localized: "Training load elevated")
        } else {
            // ratio < 0.8 (detraining)
            let deficit = min(1, (0.8 - ratio) / 0.3) // 0.8→0.5 maps to 0→1
            score = 20 + deficit * 30 // 20→50
            detail = String(localized: "Training volume declining")
        }

        return ScoredContribution(
            value: score,
            contribution: .init(
                factor: .activityLoad,
                rawScore: score,
                weight: activityWeight,
                detail: detail
            )
        )
    }

    // MARK: - Trend

    private func computeTrend(from averages: [Input.DailyAverage]) -> TrendDirection {
        guard averages.count >= 14 else { return .insufficient }

        let sorted = averages.sorted { $0.date < $1.date }
        let midpoint = sorted.count / 2
        let olderHalf = Array(sorted.prefix(midpoint))
        let recentHalf = Array(sorted.suffix(midpoint))

        let olderValues = olderHalf.map(\.value)
        let recentValues = recentHalf.map(\.value)

        let olderMean = olderValues.reduce(0, +) / Double(olderValues.count)
        let recentMean = recentValues.reduce(0, +) / Double(recentValues.count)

        guard olderMean > 0 else { return .insufficient }

        // Compute CV for each half
        let olderCV = coefficientOfVariation(olderValues)
        let recentCV = coefficientOfVariation(recentValues)

        let cvDelta = recentCV - olderCV

        // If recent CV is noticeably higher → worsening (more variable = more stressed)
        // If recent CV is noticeably lower → improving
        if cvDelta > 0.03 {
            return .rising // stress worsening
        } else if cvDelta < -0.03 {
            return .falling // stress improving
        } else {
            return .stable
        }
    }

    private func coefficientOfVariation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        let variance = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance) / mean
    }
}
