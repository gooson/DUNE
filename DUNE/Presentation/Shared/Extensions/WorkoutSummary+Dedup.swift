import Foundation

extension Array where Element == WorkoutSummary {
    /// Filters out HealthKit workouts that duplicate app-created SwiftData records.
    ///
    /// Strategy:
    /// - **Primary**: Match by `healthKitWorkoutID` (links SwiftData → HealthKit record)
    /// - **Fallback**: If `isFromThisApp` AND a date-proximate record exists, assume duplicate
    ///   (handles HealthKit write failures where `healthKitWorkoutID` was never populated)
    ///
    /// Watch workouts share the parent iOS app's bundle ID, so `isFromThisApp` alone
    /// cannot distinguish Watch vs iOS workouts. Without the date-proximity check,
    /// Watch workouts without ExerciseRecords are incorrectly hidden.
    func filteringAppDuplicates(against records: [ExerciseRecord]) -> [WorkoutSummary] {
        let appLinkedHKIDs: Set<String> = Set(
            records.compactMap { id in
                guard let id = id.healthKitWorkoutID, !id.isEmpty else { return nil }
                return id
            }
        )

        return filter { workout in
            // Primary: exact HK ID match → ExerciseRecord covers this workout
            if appLinkedHKIDs.contains(workout.id) { return false }
            // Fallback: from this app AND a probable matching record exists (±2 min)
            // Without date check, Watch workouts with no ExerciseRecord are lost.
            if workout.isFromThisApp {
                let hasProbableMatch = records.contains { record in
                    abs(record.date.timeIntervalSince(workout.date)) < 120
                }
                if hasProbableMatch { return false }
            }
            return true
        }
    }
}
