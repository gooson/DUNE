import Foundation
import HealthKit

/// Lightweight DTO for workout write — avoids SwiftData dependency.
struct WorkoutWriteInput: Sendable {
    let startDate: Date
    let duration: TimeInterval
    let category: ExerciseCategory
    let exerciseName: String
    let estimatedCalories: Double?
    let isFromHealthKit: Bool
}

/// Protocol for testability.
protocol WorkoutWriting: Sendable {
    func saveWorkout(_ input: WorkoutWriteInput) async throws -> String
}

/// Saves completed workouts to Apple Health using HKWorkoutBuilder.
struct WorkoutWriteService: WorkoutWriting, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager = .shared) {
        self.manager = manager
    }

    func saveWorkout(_ input: WorkoutWriteInput) async throws -> String {
        // Skip records that originated from HealthKit (avoid duplicates)
        guard !input.isFromHealthKit else {
            throw WorkoutWriteError.skippedHealthKitOrigin
        }

        // Validate duration (0 < duration <= 8 hours)
        guard input.duration > 0, input.duration <= 28800 else {
            throw WorkoutWriteError.invalidDuration
        }

        // Verify HealthKit write authorization for workouts
        let workoutType = HKObjectType.workoutType()
        let authStatus = await manager.healthStore.authorizationStatus(for: workoutType)
        guard authStatus == .sharingAuthorized else {
            throw WorkoutWriteError.notAuthorized
        }

        let activityType = ExerciseCategory.hkActivityType(
            category: input.category,
            exerciseName: input.exerciseName
        )

        let store = await manager.healthStore
        let endDate = input.startDate.addingTimeInterval(input.duration)

        let config = HKWorkoutConfiguration()
        config.activityType = activityType

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: config,
            device: .local()
        )

        try await builder.beginCollection(at: input.startDate)

        // Add active energy sample if calories are valid
        if let calories = input.estimatedCalories,
           calories > 0, calories < 10000,
           !calories.isNaN, !calories.isInfinite {
            let energyType = HKQuantityType(.activeEnergyBurned)
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: energyQuantity,
                start: input.startDate,
                end: endDate
            )
            try await builder.addSamples([energySample])
        }

        try await builder.endCollection(at: endDate)

        guard let workout = try await builder.finishWorkout() else {
            throw WorkoutWriteError.builderReturnedNil
        }

        AppLogger.healthKit.info("Saved workout to HealthKit: \(workout.uuid.uuidString)")
        return workout.uuid.uuidString
    }
}

enum WorkoutWriteError: Error, LocalizedError {
    case skippedHealthKitOrigin
    case invalidDuration
    case builderReturnedNil
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .skippedHealthKitOrigin: "Workout originated from HealthKit, skipping write"
        case .invalidDuration: "Workout duration is out of valid range"
        case .builderReturnedNil: "HKWorkoutBuilder returned nil workout"
        case .notAuthorized: "HealthKit workout write permission not granted"
        }
    }
}
