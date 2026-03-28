import Foundation

/// Extracts personal records (1RM, rep-max, volume, max weight) per exercise from workout history.
enum StrengthPRService: Sendable {

    struct SetEntry: Sendable {
        let weight: Double
        let reps: Int
    }

    struct WorkoutEntry: Sendable {
        let exerciseName: String
        let date: Date
        /// Best approximation of session weight: totalWeight / setCount (avg per set).
        let bestWeight: Double
        /// Per-set data for 1RM / rep-max / volume calculation.
        let sets: [SetEntry]

        init(exerciseName: String, date: Date, bestWeight: Double, sets: [SetEntry] = []) {
            self.exerciseName = exerciseName
            self.date = date
            self.bestWeight = bestWeight
            self.sets = sets
        }
    }

    /// Standard rep counts tracked as rep-max PRs.
    static let trackedRepCounts: [Int] = [3, 5, 10]

    /// Extracts per-exercise best weight PRs from workout entries.
    /// Also computes 1RM, rep-max, and session volume when set data is available.
    static func extractPRs(
        from entries: [WorkoutEntry],
        referenceDate: Date = Date()
    ) -> [StrengthPersonalRecord] {
        guard !entries.isEmpty else { return [] }

        // Per-exercise accumulators
        var bestWeightByExercise: [String: WorkoutEntry] = [:]
        var best1RMByExercise: [String: (value: Double, date: Date)] = [:]
        var repMaxByExercise: [String: [Int: (weight: Double, date: Date)]] = [:]
        var bestVolumeByExercise: [String: (value: Double, date: Date)] = [:]

        for entry in entries {
            let name = entry.exerciseName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            // Max weight tracking (existing behavior)
            if entry.bestWeight > 0, entry.bestWeight <= 500, entry.bestWeight.isFinite {
                if let existing = bestWeightByExercise[name] {
                    if entry.bestWeight > existing.bestWeight {
                        bestWeightByExercise[name] = entry
                    }
                } else {
                    bestWeightByExercise[name] = entry
                }
            }

            // Set-level analysis
            guard !entry.sets.isEmpty else { continue }

            // 1RM estimation (Epley, reps 1-10 for accuracy)
            for set in entry.sets {
                guard set.weight > 0, set.weight <= 500, set.weight.isFinite,
                      set.reps >= 1, set.reps <= 10 else { continue }

                if let estimate = OneRMFormula.epley.estimate(weight: set.weight, reps: set.reps),
                   estimate > 0, estimate <= 750, estimate.isFinite {
                    let current = best1RMByExercise[name]?.value ?? 0
                    if estimate > current {
                        best1RMByExercise[name] = (value: estimate, date: entry.date)
                    }
                }
            }

            // Rep-max PRs (tracked rep counts: 3, 5, 10)
            for set in entry.sets {
                guard set.weight > 0, set.weight <= 500, set.weight.isFinite,
                      trackedRepCounts.contains(set.reps) else { continue }

                var exerciseRepMax = repMaxByExercise[name] ?? [:]
                let existing = exerciseRepMax[set.reps]
                if existing == nil || set.weight > existing!.weight {
                    exerciseRepMax[set.reps] = (weight: set.weight, date: entry.date)
                    repMaxByExercise[name] = exerciseRepMax
                }
            }

            // Session volume (Σ weight × reps for valid sets)
            var sessionVolume: Double = 0
            for set in entry.sets {
                guard set.weight > 0, set.weight <= 500, set.weight.isFinite,
                      set.reps >= 1, set.reps <= 100 else { continue }
                let setVolume = set.weight * Double(set.reps)
                guard setVolume.isFinite else { continue }
                sessionVolume += setVolume
            }
            if sessionVolume > 0, sessionVolume <= 100_000, sessionVolume.isFinite {
                let current = bestVolumeByExercise[name]?.value ?? 0
                if sessionVolume > current {
                    bestVolumeByExercise[name] = (value: sessionVolume, date: entry.date)
                }
            }
        }

        return bestWeightByExercise.values
            .map { entry in
                let name = entry.exerciseName.trimmingCharacters(in: .whitespaces)

                let repMaxEntries = (repMaxByExercise[name] ?? [:])
                    .map { RepMaxEntry(reps: $0.key, weight: $0.value.weight, date: $0.value.date) }
                    .sorted { $0.reps < $1.reps }

                let best1RM = best1RMByExercise[name]
                let bestVolume = bestVolumeByExercise[name]

                return StrengthPersonalRecord(
                    exerciseName: entry.exerciseName,
                    maxWeight: entry.bestWeight,
                    date: entry.date,
                    referenceDateForRecent: referenceDate,
                    estimated1RM: best1RM?.value,
                    estimated1RMDate: best1RM?.date,
                    repMaxEntries: repMaxEntries,
                    bestSessionVolume: bestVolume?.value,
                    bestSessionVolumeDate: bestVolume?.date
                )
            }
            .sorted { $0.maxWeight > $1.maxWeight }
    }
}
