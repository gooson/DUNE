import Foundation

extension Array where Element == WorkoutSummary {
    /// Filters out HealthKit workouts that duplicate app-created SwiftData records.
    ///
    /// Strategy:
    /// - **Primary**: Match by `healthKitWorkoutID` (links SwiftData → HealthKit record)
    /// - **Fallback**: If `isFromThisApp` AND a type+date-proximate record exists, assume duplicate
    ///   (handles HealthKit write failures where `healthKitWorkoutID` was never populated)
    ///
    /// Watch workouts share the parent iOS app's bundle ID, so `isFromThisApp` alone
    /// cannot distinguish Watch vs iOS workouts. Without type+date-proximity check,
    /// Watch workouts without ExerciseRecords are incorrectly hidden.
    func filteringAppDuplicates(
        against records: [ExerciseRecord],
        tombstonedIDs: Set<String> = []
    ) -> [WorkoutSummary] {
        let appLinkedHKIDs: Set<String> = Set(
            records.compactMap { id in
                guard let id = id.healthKitWorkoutID, !id.isEmpty else { return nil }
                return id
            }
        )

        return filter { workout in
            // Tombstone: user explicitly deleted this workout — never show again
            if tombstonedIDs.contains(workout.id) { return false }
            // Primary: exact HK ID match → ExerciseRecord covers this workout
            if appLinkedHKIDs.contains(workout.id) { return false }
            // Fallback: from this app AND a type+date matching record exists (±2 min)
            // Without type+date check, Watch workouts with no ExerciseRecord are lost.
            if workout.isFromThisApp {
                let hasProbableMatch = records.contains { record in
                    guard abs(record.date.timeIntervalSince(workout.date)) < 120 else {
                        return false
                    }

                    // Exact rawValue match (legacy records)
                    if record.exerciseType == workout.activityType.rawValue {
                        return true
                    }

                    // Name inference match (e.g., cardio names like "Running")
                    if let inferred = WorkoutActivityType.infer(from: record.exerciseType),
                       inferred == workout.activityType {
                        return true
                    }

                    // Strength fallback for watch/manual set records where exerciseType
                    // is user-facing name (e.g., "Bench Press"), not activity rawValue.
                    if workout.activityType.category == .strength, record.hasSetData {
                        return true
                    }

                    return false
                }
                if hasProbableMatch { return false }
            }
            return true
        }
    }
}
