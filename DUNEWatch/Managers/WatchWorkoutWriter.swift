import Foundation
import HealthKit
import OSLog

/// Creates individual HKWorkout objects per exercise on Watch.
/// After the HKLiveWorkoutBuilder discards its merged workout,
/// this writer saves separate workouts so each exercise appears
/// individually in Apple Health with its correct activity type.
enum WatchWorkoutWriter {
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "WatchWorkoutWriter")

    /// Saves a single exercise as an individual HKWorkout to HealthKit.
    /// - Parameters:
    ///   - healthStore: The shared HKHealthStore.
    ///   - exerciseName: Display name (e.g. "Bench Press").
    ///   - startDate: Exercise start time.
    ///   - duration: Exercise duration in seconds.
    ///   - calories: Active calories attributed to this exercise.
    /// - Returns: The UUID string of the saved HKWorkout, or nil on failure.
    static func saveIndividualWorkout(
        healthStore: HKHealthStore,
        exerciseName: String,
        startDate: Date,
        duration: TimeInterval,
        calories: Double?
    ) async -> String? {
        guard duration > 0, duration <= 28800 else {
            logger.warning("Invalid duration \(duration, privacy: .private) for exercise")
            return nil
        }

        // Verify HealthKit write authorization (mirrors WorkoutWriteService guard)
        let authStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        guard authStatus == .sharingAuthorized else {
            logger.warning("HealthKit workout write not authorized")
            return nil
        }

        let activityType = ExerciseCategory.hkActivityType(
            category: .strength,
            exerciseName: exerciseName
        )

        let endDate = startDate.addingTimeInterval(duration)

        let config = HKWorkoutConfiguration()
        config.activityType = activityType

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: config,
            device: .local()
        )

        do {
            try await builder.beginCollection(at: startDate)

            // Add active energy sample if valid
            if let cal = calories, cal > 0, cal < 10_000,
               !cal.isNaN, !cal.isInfinite {
                let sample = HKQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: cal),
                    start: startDate,
                    end: endDate
                )
                try await builder.addSamples([sample])
            }

            let metadata = HealthKitWorkoutTitle.metadata(exerciseName: exerciseName)
            if !metadata.isEmpty {
                try await builder.addMetadata(metadata)
            }

            try await builder.endCollection(at: endDate)

            guard let workout = try await builder.finishWorkout() else {
                logger.error("Builder returned nil for exercise")
                return nil
            }

            logger.info("Saved individual workout → \(workout.uuid.uuidString, privacy: .private)")
            return workout.uuid.uuidString
        } catch {
            logger.error("Failed to save workout: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }
}
