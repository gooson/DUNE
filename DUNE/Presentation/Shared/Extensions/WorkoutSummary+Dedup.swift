import Foundation

extension Array where Element == WorkoutSummary {
    /// Local rows to display beside visible HealthKit summaries.
    /// A set-free cardio record is a fallback only when its richer HealthKit row is unavailable.
    func localRecordsForDisplay(
        against records: [ExerciseRecord],
        tombstonedIDs: Set<String> = []
    ) -> [ExerciseRecord] {
        let visibleWorkouts = filter { !tombstonedIDs.contains($0.id) }
        let visibleIDs = Set(visibleWorkouts.map(\.id))

        return records.filter { record in
            if record.hasSetData { return true }
            guard record.duration.isFinite, record.duration > 0, record.duration <= 31_622_400,
                  record.date.timeIntervalSinceReferenceDate.isFinite else { return false }
            let activityType = WorkoutActivityType(rawValue: record.exerciseType)
                ?? record.exerciseDefinitionID.flatMap { WorkoutActivityType(rawValue: $0) }
                ?? record.exerciseDefinitionID.flatMap { WorkoutActivityType.infer(from: $0) }
                ?? WorkoutActivityType.infer(from: record.exerciseType)
            guard let activityType else { return false }
            switch activityType.category {
            case .cardio, .dance, .water, .winter, .outdoor, .multiSport, .sports, .combat: break
            default: return false
            }

            if let linkedID = record.healthKitWorkoutID, !linkedID.isEmpty {
                // A known foreign ID is authoritative even when that workout is outside this page.
                return !visibleIDs.contains(linkedID)
            }
            return !visibleWorkouts.contains { workout in
                workout.isFromThisApp
                    && abs(record.date.timeIntervalSince(workout.date)) < 120
                    && [workout].filteringAppDuplicates(against: [record]).isEmpty
            }
        }
    }

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
                    // Exact linked identities were handled above. A different linked workout
                    // must not erase a simultaneous Watch session through the legacy fallback.
                    if let linkedID = record.healthKitWorkoutID, !linkedID.isEmpty { return false }
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

                    // Custom local titles can still retain a known cardio definition ID.
                    if let definitionID = record.exerciseDefinitionID,
                       (WorkoutActivityType(rawValue: definitionID)
                        ?? WorkoutActivityType.infer(from: definitionID)) == workout.activityType {
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
