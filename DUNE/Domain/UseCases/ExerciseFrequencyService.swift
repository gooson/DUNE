import Foundation

/// Analyzes workout type distribution within a time period.
enum ExerciseFrequencyService: Sendable {

    struct WorkoutEntry: Sendable {
        let exerciseName: String
        let date: Date
    }

    /// Computes per-exercise frequency from workout entries.
    /// - Parameter entries: Flat list of (exerciseName, date) from ExerciseRecords.
    /// - Returns: ExerciseFrequency list sorted by count descending.
    static func analyze(from entries: [WorkoutEntry]) -> [ExerciseFrequency] {
        guard !entries.isEmpty else { return [] }

        // Group by exercise name
        var countByName: [String: (count: Int, lastDate: Date)] = [:]

        for entry in entries {
            let name = entry.exerciseName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            if let existing = countByName[name] {
                countByName[name] = (
                    count: existing.count + 1,
                    lastDate: max(existing.lastDate, entry.date)
                )
            } else {
                countByName[name] = (count: 1, lastDate: entry.date)
            }
        }

        let total = countByName.values.reduce(0) { $0 + $1.count }
        guard total > 0 else { return [] }

        return countByName.map { name, info in
            ExerciseFrequency(
                exerciseName: name,
                count: info.count,
                lastDate: info.lastDate,
                percentage: Double(info.count) / Double(total)
            )
        }
        .sorted { $0.count > $1.count }
    }
}
