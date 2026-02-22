import Foundation

/// Extracts personal records (session max weight) per exercise from workout history.
enum StrengthPRService: Sendable {

    struct WorkoutEntry: Sendable {
        let exerciseName: String
        let date: Date
        let maxWeight: Double  // Max weight across all sets in this session
    }

    /// Extracts per-exercise max weight PRs from workout entries.
    /// - Parameter entries: Flat list of (exercise, date, maxWeight) from ExerciseRecord+WorkoutSet.
    /// - Parameter referenceDate: Date to determine "recent" flag (default: now).
    /// - Returns: One StrengthPersonalRecord per exercise, sorted by maxWeight descending.
    static func extractPRs(
        from entries: [WorkoutEntry],
        referenceDate: Date = Date()
    ) -> [StrengthPersonalRecord] {
        guard !entries.isEmpty else { return [] }

        // Group by exercise name, find max weight entry for each
        var bestByExercise: [String: WorkoutEntry] = [:]

        for entry in entries {
            guard entry.maxWeight > 0, entry.maxWeight <= 500,
                  entry.maxWeight.isFinite else { continue }

            let name = entry.exerciseName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            if let existing = bestByExercise[name] {
                if entry.maxWeight > existing.maxWeight {
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
                    maxWeight: entry.maxWeight,
                    date: entry.date,
                    referenceDateForRecent: referenceDate
                )
            }
            .sorted { $0.maxWeight > $1.maxWeight }
    }
}
