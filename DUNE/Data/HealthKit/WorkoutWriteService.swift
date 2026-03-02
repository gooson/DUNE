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
    /// Distance in kilometers (nil for non-distance workouts).
    let distanceKm: Double?
    /// Activity type for distance type resolution (nil uses category-based fallback).
    let activityType: WorkoutActivityType?

    init(
        startDate: Date,
        duration: TimeInterval,
        category: ExerciseCategory,
        exerciseName: String,
        estimatedCalories: Double?,
        isFromHealthKit: Bool,
        distanceKm: Double? = nil,
        activityType: WorkoutActivityType? = nil
    ) {
        self.startDate = startDate
        self.duration = duration
        self.category = category
        self.exerciseName = exerciseName
        self.estimatedCalories = estimatedCalories
        self.isFromHealthKit = isFromHealthKit
        self.distanceKm = distanceKm
        self.activityType = activityType
    }
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

        let activityType = input.activityType?.hkWorkoutActivityType
            ?? ExerciseCategory.hkActivityType(
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

        // Add distance sample if valid
        if let distanceKm = input.distanceKm,
           distanceKm > 0, distanceKm < 500,
           !distanceKm.isNaN, !distanceKm.isInfinite {
            let distanceType = Self.distanceQuantityType(for: activityType)
            let distanceMeters = distanceKm * 1000.0
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: input.startDate,
                end: endDate
            )
            try await builder.addSamples([distanceSample])
        }

        try await builder.endCollection(at: endDate)

        guard let workout = try await builder.finishWorkout() else {
            throw WorkoutWriteError.builderReturnedNil
        }

        AppLogger.healthKit.info("Saved workout to HealthKit: \(workout.uuid.uuidString)")
        return workout.uuid.uuidString
    }
}

private extension WorkoutWriteService {
    /// Resolves the appropriate HKQuantityType for distance based on workout activity type.
    static func distanceQuantityType(for activityType: HKWorkoutActivityType) -> HKQuantityType {
        switch activityType {
        case .cycling, .handCycling:
            return HKQuantityType(.distanceCycling)
        case .swimming:
            return HKQuantityType(.distanceSwimming)
        default:
            return HKQuantityType(.distanceWalkingRunning)
        }
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
