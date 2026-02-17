import Foundation

extension Array where Element == WorkoutSummary {
    /// Filters out HealthKit workouts that duplicate app-created SwiftData records.
    /// Primary: match by `healthKitWorkoutID`. Fallback: exclude own app's `bundleIdentifier`.
    func filteringAppDuplicates(against records: [ExerciseRecord]) -> [WorkoutSummary] {
        let appLinkedHKIDs: Set<String> = Set(records.compactMap(\.healthKitWorkoutID))
        let appBundleID = Bundle.main.bundleIdentifier ?? ""

        return filter { workout in
            if appLinkedHKIDs.contains(workout.id) { return false }
            if workout.sourceBundleIdentifier == appBundleID { return false }
            return true
        }
    }
}
