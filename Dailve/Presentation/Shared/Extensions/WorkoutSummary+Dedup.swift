import Foundation

extension Array where Element == WorkoutSummary {
    /// Filters out HealthKit workouts that duplicate app-created SwiftData records.
    ///
    /// Strategy:
    /// - **Primary**: Match by `healthKitWorkoutID` (links SwiftData → HealthKit record)
    /// - **Fallback**: Exclude workouts where `isFromThisApp == true` (handles HealthKit write
    ///   failures where `healthKitWorkoutID` was never populated on the SwiftData side)
    func filteringAppDuplicates(against records: [ExerciseRecord]) -> [WorkoutSummary] {
        let appLinkedHKIDs: Set<String> = Set(
            records.compactMap { id in
                guard let id = id.healthKitWorkoutID, !id.isEmpty else { return nil }
                return id
            }
        )

        return filter { workout in
            if appLinkedHKIDs.contains(workout.id) { return false }
            if workout.isFromThisApp { return false }
            return true
        }
    }
}
