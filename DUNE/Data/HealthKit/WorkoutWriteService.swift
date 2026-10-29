import Foundation
import HealthKit
import CoreLocation

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
    /// Step count collected during the workout.
    let stepCount: Int?
    /// Average pace in sec/km.
    let averagePaceSecondsPerKm: Double?
    /// Average cadence in steps/min.
    let averageCadenceStepsPerMinute: Double?
    /// Elevation gain in meters.
    let elevationGainMeters: Double?
    /// Floors ascended from motion sensors.
    let floorsAscended: Double?
    /// Activity type for distance type resolution (nil uses category-based fallback).
    let activityType: WorkoutActivityType?
    let isIndoor: Bool?
    let routePoints: [WorkoutRoutePoint]
    let endDate: Date?
    let pauseIntervals: [DateInterval]

    init(
        startDate: Date,
        duration: TimeInterval,
        category: ExerciseCategory,
        exerciseName: String,
        estimatedCalories: Double?,
        isFromHealthKit: Bool,
        distanceKm: Double? = nil,
        stepCount: Int? = nil,
        averagePaceSecondsPerKm: Double? = nil,
        averageCadenceStepsPerMinute: Double? = nil,
        elevationGainMeters: Double? = nil,
        floorsAscended: Double? = nil,
        activityType: WorkoutActivityType? = nil,
        isIndoor: Bool? = nil,
        routePoints: [WorkoutRoutePoint] = [],
        endDate: Date? = nil,
        pauseIntervals: [DateInterval] = []
    ) {
        self.startDate = startDate
        self.duration = duration
        self.category = category
        self.exerciseName = exerciseName
        self.estimatedCalories = estimatedCalories
        self.isFromHealthKit = isFromHealthKit
        self.distanceKm = distanceKm
        self.stepCount = stepCount
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.averageCadenceStepsPerMinute = averageCadenceStepsPerMinute
        self.elevationGainMeters = elevationGainMeters
        self.floorsAscended = floorsAscended
        self.activityType = activityType
        self.isIndoor = isIndoor
        self.routePoints = isIndoor == true ? [] : WorkoutLocationPayload.normalizedRoute(routePoints)
        self.endDate = endDate
        self.pauseIntervals = pauseIntervals
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
        let endDate = input.endDate ?? input.startDate.addingTimeInterval(input.duration)
        guard input.startDate.timeIntervalSinceReferenceDate.isFinite,
              endDate.timeIntervalSinceReferenceDate.isFinite,
              endDate > input.startDate,
              endDate.timeIntervalSince(input.startDate) <= 86_400 else {
            throw WorkoutWriteError.invalidDuration
        }

        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = input.isIndoor.map { $0 ? .indoor : .outdoor } ?? .unknown

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: config,
            device: .local()
        )

        try await builder.beginCollection(at: input.startDate)

        var samples: [HKSample] = []

        // Add active energy sample if calories are valid
        if let calories = input.estimatedCalories,
           calories > 0, calories < 10000,
           !calories.isNaN, !calories.isInfinite {
            let energyType = HKQuantityType(.activeEnergyBurned)
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            samples.append(HKQuantitySample(
                type: energyType,
                quantity: energyQuantity,
                start: input.startDate,
                end: endDate
            ))
        }

        // Add distance sample if valid
        if let distanceKm = input.distanceKm,
           distanceKm > 0, distanceKm < 500,
           !distanceKm.isNaN, !distanceKm.isInfinite {
            let distanceType = Self.distanceQuantityType(for: activityType)
            let distanceMeters = distanceKm * 1000.0
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
            samples.append(HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: input.startDate,
                end: endDate
            ))
        }

        // Add step sample if valid.
        if let stepCount = input.stepCount,
           stepCount > 0, stepCount < 300_000 {
            let quantity = HKQuantity(unit: .count(), doubleValue: Double(stepCount))
            samples.append(HKQuantitySample(
                type: HKQuantityType(.stepCount),
                quantity: quantity,
                start: input.startDate,
                end: endDate
            ))
        }

        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }

        var metadata: [String: Any] = [:]
        if let isIndoor = input.isIndoor { metadata[HKMetadataKeyIndoorWorkout] = isIndoor }
        let pauseEvents = input.pauseIntervals.filter {
            $0.start >= input.startDate && $0.end <= endDate && $0.duration > 0
        }.flatMap { interval in
            [HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: interval.start, duration: 0), metadata: nil),
             HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: interval.end, duration: 0), metadata: nil)]
        }
        if !pauseEvents.isEmpty { try await builder.addWorkoutEvents(pauseEvents) }

        if let elevation = input.elevationGainMeters,
           elevation > 0, elevation.isFinite, elevation < 20_000 {
            metadata[HKMetadataKeyElevationAscended] = HKQuantity(
                unit: .meter(),
                doubleValue: elevation
            )
        } else if let floors = input.floorsAscended,
                  floors > 0, floors.isFinite, floors < 20_000 {
            metadata[HKMetadataKeyElevationAscended] = HKQuantity(
                unit: .meter(),
                doubleValue: floors * 3.0
            )
        }

        if let pace = input.averagePaceSecondsPerKm,
           pace > 0, pace.isFinite, pace < 3600 {
            metadata["com.dune.workout.averagePaceSecPerKm"] = pace
        }

        if let cadence = input.averageCadenceStepsPerMinute,
           cadence > 0, cadence.isFinite, cadence < 300 {
            metadata["com.dune.workout.averageCadenceSPM"] = cadence
        }

        metadata.merge(
            HealthKitWorkoutTitle.metadata(exerciseName: input.exerciseName),
            uniquingKeysWith: { _, new in new }
        )

        if !metadata.isEmpty {
            try await builder.addMetadata(metadata)
        }

        try await builder.endCollection(at: endDate)

        guard let workout = try await builder.finishWorkout() else {
            throw WorkoutWriteError.builderReturnedNil
        }

        // A route is optional enrichment. Once the workout is saved, route failures must
        // never trigger a workout retry (which would create a duplicate).
        if !input.routePoints.isEmpty,
           store.authorizationStatus(for: HKSeriesType.workoutRoute()) == .sharingAuthorized {
            do {
                try await saveRoutes(input.routePoints, workout: workout, store: store)
            } catch {
                AppLogger.healthKit.warning("Workout saved; optional route write failed: \(error)")
            }
        }

        AppLogger.healthKit.info("Saved workout to HealthKit: \(workout.uuid.uuidString)")
        return workout.uuid.uuidString
    }
}

private extension WorkoutWriteService {
    func saveRoutes(_ points: [WorkoutRoutePoint], workout: HKWorkout, store: HKHealthStore) async throws {
        var segments: [[CLLocation]] = []
        for point in points where point.timestamp >= workout.startDate && point.timestamp <= workout.endDate {
            if point.startsNewSegment || segments.isEmpty { segments.append([]) }
            segments[segments.count - 1].append(CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                altitude: point.altitude ?? 0,
                horizontalAccuracy: point.horizontalAccuracy ?? 10,
                verticalAccuracy: point.altitude == nil ? -1 : 10,
                timestamp: point.timestamp
            ))
        }
        // Separate HK routes preserve pause/jump gaps when this workout is imported again.
        for segment in segments where segment.count >= 2 {
            try Task.checkCancellation()
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
            try await routeBuilder.insertRouteData(segment)
            _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }
    }

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
