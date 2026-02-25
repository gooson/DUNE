import Foundation

/// Computes compound fatigue scores for each muscle group using exponential decay.
protocol FatigueCalculating: Sendable {
    func computeCompoundFatigue(
        for muscles: [MuscleGroup],
        from records: [ExerciseRecordSnapshot],
        sleepModifier: Double,
        readinessModifier: Double,
        referenceDate: Date
    ) -> [CompoundFatigueScore]
}

struct FatigueCalculationService: FatigueCalculating, Sendable {

    /// How many days of history to consider.
    private let lookbackDays = 14

    /// Default body weight for normalizing volume load (kg).
    private let defaultBodyWeight: Double = 70.0

    /// Saturation thresholds per muscle size — the cumulative load at which
    /// normalized fatigue reaches 1.0 (Level 10) if sustained.
    private enum Saturation {
        /// Large muscles: quads, hamstrings, glutes, back, lats
        static let large: Double = 15.0
        /// Medium muscles: chest, shoulders, traps
        static let medium: Double = 12.0
        /// Small muscles: biceps, triceps, forearms, core, calves
        static let small: Double = 10.0
    }

    // MARK: - Engagement

    /// Primary muscle gets full load contribution.
    private let primaryEngagement: Double = 1.0
    /// Secondary muscle gets partial load contribution.
    private let secondaryEngagement: Double = 0.4

    // MARK: - Public API

    func computeCompoundFatigue(
        for muscles: [MuscleGroup],
        from records: [ExerciseRecordSnapshot],
        sleepModifier: Double,
        readinessModifier: Double,
        referenceDate: Date
    ) -> [CompoundFatigueScore] {
        let cutoffDate = Calendar.current.date(
            byAdding: .day, value: -lookbackDays, to: referenceDate
        ) ?? referenceDate
        let relevantRecords = records.filter { $0.date >= cutoffDate && $0.date <= referenceDate }

        // Clamp modifiers to safe ranges
        let clampedSleep = Swift.max(0.5, Swift.min(sleepModifier, 1.25))
        let clampedReadiness = Swift.max(0.6, Swift.min(readinessModifier, 1.20))

        return muscles.map { muscle in
            computeScore(
                for: muscle,
                records: relevantRecords,
                sleepModifier: clampedSleep,
                readinessModifier: clampedReadiness,
                referenceDate: referenceDate
            )
        }
    }

    // MARK: - Per-Muscle Computation

    private func computeScore(
        for muscle: MuscleGroup,
        records: [ExerciseRecordSnapshot],
        sleepModifier: Double,
        readinessModifier: Double,
        referenceDate: Date
    ) -> CompoundFatigueScore {
        // Modifier > 1 means faster recovery → tau should be SMALLER
        // So we divide tau by the combined modifier.
        let baseTau = muscle.recoveryHours * 2.0
        let combinedModifier = sleepModifier * readinessModifier
        let effectiveTau = Swift.max(baseTau / Swift.max(combinedModifier, 0.1), 1.0)

        var contributions: [WorkoutContribution] = []
        var totalDecayedLoad: Double = 0

        for record in records {
            let engagement = muscleEngagement(for: muscle, in: record)
            guard engagement > 0 else { continue }

            let rawLoad = sessionLoad(from: record) * engagement
            guard rawLoad > 0, rawLoad.isFinite else { continue }

            let hoursSince = Swift.max(0, referenceDate.timeIntervalSince(record.date) / 3600.0)
            guard hoursSince.isFinite else { continue }

            // Exponential decay: e^(-hoursSince / tau)
            let exponent = -hoursSince / effectiveTau
            // Guard against extreme exponents (exp(-700) underflows to 0, which is fine)
            let decayFactor = exponent > -500 ? exp(exponent) : 0
            guard decayFactor.isFinite else { continue }

            let decayedLoad = rawLoad * decayFactor
            guard decayedLoad.isFinite else { continue }

            totalDecayedLoad += decayedLoad
            contributions.append(WorkoutContribution(
                date: record.date,
                exerciseName: record.exerciseName,
                rawLoad: rawLoad,
                decayedLoad: decayedLoad
            ))
        }

        // Normalize to 0.0 ~ 1.0
        let threshold = saturationThreshold(for: muscle)
        let normalizedScore: Double
        if totalDecayedLoad > 0, threshold > 0 {
            normalizedScore = Swift.min(totalDecayedLoad / threshold, 1.0)
        } else {
            normalizedScore = 0
        }

        let level: FatigueLevel = contributions.isEmpty
            ? .noData
            : FatigueLevel.from(normalizedScore: normalizedScore)

        let breakdown = FatigueBreakdown(
            workoutContributions: contributions.sorted { $0.date > $1.date },
            baseFatigue: totalDecayedLoad,
            sleepModifier: sleepModifier,
            readinessModifier: readinessModifier,
            effectiveTau: effectiveTau
        )

        return CompoundFatigueScore(
            muscle: muscle,
            normalizedScore: normalizedScore,
            level: level,
            breakdown: breakdown
        )
    }

    // MARK: - Session Load Calculation

    /// Calculates raw load for one workout session (before decay and engagement).
    func sessionLoad(from record: ExerciseRecordSnapshot) -> Double {
        // Strategy 1: Weight-based (strength training with set data)
        if let weight = record.totalWeight, weight > 0,
           let reps = record.totalReps, reps > 0 {
            // Volume = totalWeight * totalReps / bodyWeight (normalized)
            let volume = (weight * Double(reps)) / defaultBodyWeight
            guard volume.isFinite, !volume.isNaN else { return fallbackLoad(from: record) }
            // Scale down to reasonable range (a 100kg squat 5x5 = 100*25/70 ≈ 35.7)
            // Dividing by 100 gives ~0.36 per session
            return volume / 100.0
        }

        // Strategy 2: Cardio (distance + duration)
        if let distance = record.distanceKm, distance > 0,
           let duration = record.durationMinutes, duration > 0 {
            // Load = distance * sqrt(duration/60)
            // 5km in 30min = 5 * sqrt(0.5) ≈ 3.54, 20km in 120min = 20 * sqrt(2) ≈ 28.3
            let load = distance * sqrt(Swift.max(duration / 60.0, 0.01))
            guard load.isFinite, !load.isNaN else { return fallbackLoad(from: record) }
            return load / 10.0  // Scale: 5km/30min → ~0.35
        }

        // Strategy 3: Duration-only (cardio without distance)
        if let duration = record.durationMinutes, duration > 0 {
            return duration / 60.0  // 60min = 1.0 load unit
        }

        return fallbackLoad(from: record)
    }

    /// Fallback: use set count as a rough proxy.
    private func fallbackLoad(from record: ExerciseRecordSnapshot) -> Double {
        let sets = Double(record.completedSetCount)
        return sets > 0 ? sets * 0.1 : 0.05  // Minimum non-zero for records that exist
    }

    // MARK: - Helpers

    private func muscleEngagement(for muscle: MuscleGroup, in record: ExerciseRecordSnapshot) -> Double {
        if record.primaryMuscles.contains(muscle) {
            return primaryEngagement
        }
        if record.secondaryMuscles.contains(muscle) {
            return secondaryEngagement
        }
        return 0
    }

    private func saturationThreshold(for muscle: MuscleGroup) -> Double {
        switch muscle {
        case .quadriceps, .hamstrings, .glutes, .back, .lats:
            return Saturation.large
        case .chest, .shoulders, .traps:
            return Saturation.medium
        case .biceps, .triceps, .forearms, .core, .calves:
            return Saturation.small
        }
    }
}
