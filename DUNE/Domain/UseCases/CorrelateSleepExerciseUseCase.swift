import Foundation

protocol SleepExerciseCorrelating: Sendable {
    func execute(input: CorrelateSleepExerciseUseCase.Input) -> SleepExerciseCorrelation
}

/// Correlates exercise patterns with subsequent sleep quality.
///
/// Pairs each night's sleep data with the previous day's exercise to find
/// which exercise intensities yield the best sleep outcomes.
struct CorrelateSleepExerciseUseCase: SleepExerciseCorrelating, Sendable {

    struct Input: Sendable {
        /// Sleep data keyed by date (the night of sleep).
        let sleepByDate: [SleepDay]
        /// Exercise data keyed by date (the day of exercise).
        let exerciseByDate: [ExerciseDay]

        struct SleepDay: Sendable {
            let date: Date
            let score: Int
            let deepRatio: Double
            let efficiency: Double
        }

        struct ExerciseDay: Sendable {
            let date: Date
            /// 0.0 (rest) to 1.0 (max effort).
            let maxIntensity: Double
        }
    }

    func execute(input: Input) -> SleepExerciseCorrelation {
        let calendar = Calendar.current

        // Build exercise lookup by day
        var exerciseLookup: [DateComponents: Input.ExerciseDay] = [:]
        for ex in input.exerciseByDate {
            let key = calendar.dateComponents([.year, .month, .day], from: ex.date)
            if let existing = exerciseLookup[key] {
                if ex.maxIntensity > existing.maxIntensity {
                    exerciseLookup[key] = ex
                }
            } else {
                exerciseLookup[key] = ex
            }
        }

        // Match: sleep date D → exercise date D-1
        typealias Pair = (band: SleepExerciseCorrelation.IntensityBand, sleep: Input.SleepDay)
        var pairs: [Pair] = []

        for sleep in input.sleepByDate {
            let prevDay = calendar.date(byAdding: .day, value: -1, to: sleep.date)!
            let prevKey = calendar.dateComponents([.year, .month, .day], from: prevDay)

            let intensity: Double
            if let ex = exerciseLookup[prevKey] {
                intensity = ex.maxIntensity
            } else {
                intensity = 0
            }

            let band = SleepExerciseCorrelation.IntensityBand.from(intensity: intensity)
            pairs.append((band, sleep))
        }

        // Group by intensity band
        var grouped: [SleepExerciseCorrelation.IntensityBand: [Input.SleepDay]] = [:]
        for pair in pairs {
            grouped[pair.band, default: []].append(pair.sleep)
        }

        // Compute stats per band
        var breakdown: [SleepExerciseCorrelation.IntensityBand: SleepExerciseCorrelation.SleepStats] = [:]
        for (band, sleeps) in grouped {
            guard !sleeps.isEmpty else { continue }
            let count = Double(sleeps.count)
            breakdown[band] = SleepExerciseCorrelation.SleepStats(
                avgScore: sleeps.reduce(0.0) { $0 + Double($1.score) } / count,
                avgDeepRatio: sleeps.reduce(0.0) { $0 + $1.deepRatio } / count,
                avgEfficiency: sleeps.reduce(0.0) { $0 + $1.efficiency } / count,
                sampleCount: sleeps.count
            )
        }

        let confidence = computeConfidence(pairs.count)
        let insight = generateInsight(breakdown: breakdown, confidence: confidence)

        return SleepExerciseCorrelation(
            dataPointCount: pairs.count,
            confidence: confidence,
            intensityBreakdown: breakdown,
            overallInsight: insight
        )
    }

    private func computeConfidence(_ count: Int) -> SleepExerciseCorrelation.Confidence {
        switch count {
        case ..<14: .low
        case 14...30: .medium
        default: .high
        }
    }

    private func generateInsight(
        breakdown: [SleepExerciseCorrelation.IntensityBand: SleepExerciseCorrelation.SleepStats],
        confidence: SleepExerciseCorrelation.Confidence
    ) -> String? {
        guard confidence != .low else { return nil }
        guard let bestBand = breakdown.max(by: { $0.value.avgScore < $1.value.avgScore }) else { return nil }

        let improvement: String
        if let restStats = breakdown[.rest] {
            let diff = bestBand.value.avgScore - restStats.avgScore
            if diff > 5 {
                improvement = String(localized: "\(Int(diff))% better than rest days")
            } else {
                return nil
            }
        } else {
            improvement = ""
        }

        if improvement.isEmpty {
            return String(localized: "Best sleep after \(bestBand.key.displayName.lowercased()) workouts")
        }
        return String(localized: "Best sleep after \(bestBand.key.displayName.lowercased()) workouts — \(improvement)")
    }
}
