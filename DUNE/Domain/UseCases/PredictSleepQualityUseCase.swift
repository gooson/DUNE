import Foundation

protocol SleepQualityPredicting: Sendable {
    func execute(input: PredictSleepQualityUseCase.Input) -> SleepQualityPrediction
}

/// Predicts tonight's sleep quality from today's activity and recent sleep patterns.
///
/// Weights: recentSleepAverage(40%) + workoutEffect(20%) + hrvTrend(15%)
///        + bedtimeConsistency(15%) + conditionScore(10%)
struct PredictSleepQualityUseCase: SleepQualityPredicting, Sendable {

    struct Input: Sendable {
        /// Recent nightly sleep scores (most recent first), up to 14 days.
        let recentSleepScores: [Int]
        /// Today's workout intensity (0.0 = rest day, 1.0 = maximum effort).
        let todayWorkoutIntensity: Double
        /// HRV trend direction.
        let hrvTrend: TrendDirection
        /// Standard deviation of bedtime over recent nights (minutes).
        let bedtimeVarianceMinutes: Double
        /// Today's condition score (0-100), if available.
        let conditionScore: Int?
        /// Number of days of sleep data available.
        let dataAvailableDays: Int
    }

    // MARK: - Weights (total = 1.0)

    private let recentSleepWeight = 0.40
    private let workoutEffectWeight = 0.20
    private let hrvTrendWeight = 0.15
    private let bedtimeConsistencyWeight = 0.15
    private let conditionWeight = 0.10

    // MARK: - Thresholds

    /// Optimal workout intensity range for sleep benefit.
    private let optimalIntensityRange = 0.3...0.7
    /// Bedtime variance (minutes) above which consistency is poor.
    private let bedtimeVarianceThreshold = 60.0
    /// Bedtime variance for zero consistency score.
    private let bedtimeVarianceMax = 120.0

    func execute(input: Input) -> SleepQualityPrediction {
        var factors: [SleepQualityPrediction.PredictionFactor] = []
        var tips: [String] = []

        let recentSleep = computeRecentSleepScore(input.recentSleepScores)
        let workoutEffect = computeWorkoutEffect(input.todayWorkoutIntensity)
        let hrvEffect = computeHRVTrendEffect(input.hrvTrend)
        let consistencyEffect = computeBedtimeConsistency(input.bedtimeVarianceMinutes)
        let conditionEffect = computeConditionEffect(input.conditionScore)

        // Build factors
        if !input.recentSleepScores.isEmpty {
            let avg = input.recentSleepScores.reduce(0, +) / max(1, input.recentSleepScores.count)
            let impact: SleepQualityPrediction.Impact = avg >= 60 ? .positive : (avg >= 40 ? .neutral : .negative)
            factors.append(.init(
                type: .recentSleepPattern,
                impact: impact,
                detail: String(localized: "Recent sleep average: \(avg)")
            ))
        }

        let workoutImpact: SleepQualityPrediction.Impact
        if optimalIntensityRange.contains(input.todayWorkoutIntensity) {
            workoutImpact = .positive
        } else if input.todayWorkoutIntensity > 0.85 {
            workoutImpact = .negative
            tips.append(String(localized: "Very intense workouts can disrupt sleep"))
        } else if input.todayWorkoutIntensity < 0.1 {
            workoutImpact = .neutral
            tips.append(String(localized: "Light activity during the day can improve sleep"))
        } else {
            workoutImpact = .neutral
        }
        factors.append(.init(
            type: .workoutEffect,
            impact: workoutImpact,
            detail: formatWorkoutDetail(input.todayWorkoutIntensity)
        ))

        let hrvImpact: SleepQualityPrediction.Impact = switch input.hrvTrend {
        case .rising: .positive
        case .falling: .negative
        case .stable, .volatile, .insufficient: .neutral
        }
        factors.append(.init(
            type: .hrvTrend,
            impact: hrvImpact,
            detail: formatHRVDetail(input.hrvTrend)
        ))

        if input.bedtimeVarianceMinutes > bedtimeVarianceThreshold {
            factors.append(.init(
                type: .bedtimeConsistency,
                impact: .negative,
                detail: String(localized: "Bedtime varies by \(Int(input.bedtimeVarianceMinutes)) min")
            ))
            tips.append(String(localized: "A consistent bedtime improves sleep quality"))
        } else {
            factors.append(.init(
                type: .bedtimeConsistency,
                impact: .positive,
                detail: String(localized: "Consistent bedtime schedule")
            ))
        }

        if let score = input.conditionScore {
            let condImpact: SleepQualityPrediction.Impact = score >= 60 ? .positive : (score >= 40 ? .neutral : .negative)
            factors.append(.init(
                type: .conditionLevel,
                impact: condImpact,
                detail: String(localized: "Condition score: \(score)")
            ))
        }

        let rawScore = recentSleep * recentSleepWeight
            + workoutEffect * workoutEffectWeight
            + hrvEffect * hrvTrendWeight
            + consistencyEffect * bedtimeConsistencyWeight
            + conditionEffect * conditionWeight

        let predictedScore = Int(rawScore * 100)
        let confidence = computeConfidence(input.dataAvailableDays)

        return SleepQualityPrediction(
            predictedScore: predictedScore,
            confidence: confidence,
            factors: factors,
            tips: tips
        )
    }

    // MARK: - Component Calculations

    /// Returns 0.0-1.0 based on average of recent sleep scores.
    private func computeRecentSleepScore(_ scores: [Int]) -> Double {
        guard !scores.isEmpty else { return 0.5 }
        let avg = Double(scores.reduce(0, +)) / Double(scores.count)
        return min(1.0, max(0.0, avg / 100.0))
    }

    /// Returns 0.0-1.0 based on workout intensity impact on sleep.
    /// Moderate exercise improves sleep; very intense or no exercise is less beneficial.
    private func computeWorkoutEffect(_ intensity: Double) -> Double {
        let clamped = min(1.0, max(0.0, intensity))
        if optimalIntensityRange.contains(clamped) {
            return 0.8 + (0.2 * (1.0 - abs(clamped - 0.5) / 0.2))
        } else if clamped < 0.1 {
            return 0.4
        } else if clamped > 0.85 {
            // Very intense exercise can disrupt sleep
            return max(0.2, 0.8 - (clamped - 0.85) * 4.0)
        } else {
            return 0.6
        }
    }

    /// Returns 0.0-1.0 based on HRV trend direction.
    private func computeHRVTrendEffect(_ trend: TrendDirection) -> Double {
        switch trend {
        case .rising: 0.9
        case .stable: 0.6
        case .falling: 0.3
        case .volatile: 0.4
        case .insufficient: 0.5
        }
    }

    /// Returns 0.0-1.0 based on bedtime consistency.
    private func computeBedtimeConsistency(_ varianceMinutes: Double) -> Double {
        guard varianceMinutes > 0 else { return 1.0 }
        if varianceMinutes <= bedtimeVarianceThreshold {
            return 1.0 - (varianceMinutes / bedtimeVarianceThreshold) * 0.2
        }
        let excess = varianceMinutes - bedtimeVarianceThreshold
        let range = bedtimeVarianceMax - bedtimeVarianceThreshold
        guard range > 0 else { return 0.2 }
        return max(0.2, 0.8 - (excess / range) * 0.6)
    }

    /// Returns 0.0-1.0 based on condition score.
    private func computeConditionEffect(_ score: Int?) -> Double {
        guard let score else { return 0.5 }
        return min(1.0, max(0.0, Double(score) / 100.0))
    }

    /// Determines confidence based on data availability.
    private func computeConfidence(_ days: Int) -> SleepQualityPrediction.Confidence {
        switch days {
        case 0..<7: .low
        case 7..<14: .medium
        default: .high
        }
    }

    // MARK: - Formatting

    private func formatWorkoutDetail(_ intensity: Double) -> String {
        if intensity < 0.1 {
            return String(localized: "Rest day")
        } else if intensity < 0.4 {
            return String(localized: "Light workout today")
        } else if intensity < 0.7 {
            return String(localized: "Moderate workout today")
        } else {
            return String(localized: "Intense workout today")
        }
    }

    private func formatHRVDetail(_ trend: TrendDirection) -> String {
        switch trend {
        case .rising: String(localized: "HRV trending up")
        case .falling: String(localized: "HRV trending down")
        case .stable: String(localized: "HRV stable")
        case .volatile: String(localized: "HRV fluctuating")
        case .insufficient: String(localized: "Not enough HRV data")
        }
    }
}
