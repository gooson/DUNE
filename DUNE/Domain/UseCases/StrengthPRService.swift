import Foundation

/// Extracts personal records (best average weight per set) per exercise from workout history.
enum StrengthPRService: Sendable {

    struct WorkoutEntry: Sendable {
        let exerciseName: String
        let date: Date
        /// Best approximation of session weight: totalWeight / setCount (avg per set).
        let bestWeight: Double
    }

    /// Extracts per-exercise best weight PRs from workout entries.
    /// - Parameter entries: Flat list of (exercise, date, bestWeight) from ExerciseRecord snapshots.
    /// - Parameter referenceDate: Date to determine "recent" flag (default: now).
    /// - Returns: One StrengthPersonalRecord per exercise, sorted by bestWeight descending.
    static func extractPRs(
        from entries: [WorkoutEntry],
        referenceDate: Date = Date()
    ) -> [StrengthPersonalRecord] {
        guard !entries.isEmpty else { return [] }

        // Group by exercise name, find max weight entry for each
        var bestByExercise: [String: WorkoutEntry] = [:]

        for entry in entries {
            guard entry.bestWeight > 0, entry.bestWeight <= 500,
                  entry.bestWeight.isFinite else { continue }

            let name = entry.exerciseName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            if let existing = bestByExercise[name] {
                if entry.bestWeight > existing.bestWeight {
                    bestByExercise[name] = entry
                }
            } else {
                bestByExercise[name] = entry
            }
        }

        return bestByExercise.values
            .map { entry in
                StrengthPersonalRecord(
                    exerciseName: entry.exerciseName,
                    maxWeight: entry.bestWeight,
                    date: entry.date,
                    referenceDateForRecent: referenceDate
                )
            }
            .sorted { $0.maxWeight > $1.maxWeight }
    }
}
