import HealthKit

protocol WorkoutQuerying: Sendable {
    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary]
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary]
}

struct WorkoutQueryService: WorkoutQuerying, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        try await manager.ensureNotDenied(for: HKObjectType.workoutType())
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )

        let workouts = try await manager.execute(descriptor)

        return workouts.map { workout in
            toSummary(workout)
        }
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        try await manager.ensureNotDenied(for: HKObjectType.workoutType())

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )

        let workouts = try await manager.execute(descriptor)

        return workouts.map { workout in
            toSummary(workout)
        }
    }

    // MARK: - HKWorkout → WorkoutSummary

    private func toSummary(_ workout: HKWorkout) -> WorkoutSummary {
        let activityType = WorkoutActivityType(healthKit: workout.workoutActivityType)

        // Calories
        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        // Distance — try activity-specific types first, fall back to walking/running
        let distance = extractDistance(workout)

        // Heart rate statistics
        let hrStats = workout.statistics(for: HKQuantityType(.heartRate))
        let hrAvg = validHR(hrStats?.averageQuantity()?.doubleValue(for: .bpmUnit))
        let hrMax = validHR(hrStats?.maximumQuantity()?.doubleValue(for: .bpmUnit))
        let hrMin = validHR(hrStats?.minimumQuantity()?.doubleValue(for: .bpmUnit))

        // Pace / Speed
        let paceAndSpeed = extractPaceAndSpeed(workout, activityType: activityType)

        // Elevation
        let elevation = extractElevation(workout.metadata)

        // Weather
        let (temp, condition, humidity) = extractWeather(workout.metadata)

        // Indoor
        let isIndoor = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool

        // Step count
        let stepCount = workout.statistics(for: HKQuantityType(.stepCount))?
            .sumQuantity()?.doubleValue(for: .count())

        // Milestone detection
        let milestone = MilestoneDistance.detect(from: distance)

        return WorkoutSummary(
            id: workout.uuid.uuidString,
            type: activityType.typeName,
            activityType: activityType,
            duration: workout.duration,
            calories: calories,
            distance: distance,
            date: workout.startDate,
            isFromThisApp: workout.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier,
            heartRateAvg: hrAvg,
            heartRateMax: hrMax,
            heartRateMin: hrMin,
            averagePace: paceAndSpeed.pace,
            averageSpeed: paceAndSpeed.speed,
            elevationAscended: elevation,
            weatherTemperature: temp,
            weatherCondition: condition,
            weatherHumidity: humidity,
            isIndoor: isIndoor,
            stepCount: stepCount,
            milestoneDistance: milestone
        )
    }

    // MARK: - Extraction helpers

    private func extractDistance(_ workout: HKWorkout) -> Double? {
        // Try walking/running first (most common) — max 500km per workout
        if let d = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .meter()), d > 0, d.isFinite, d < 500_000 {
            return d
        }
        // Cycling
        if let d = workout.statistics(for: HKQuantityType(.distanceCycling))?
            .sumQuantity()?.doubleValue(for: .meter()), d > 0, d.isFinite, d < 500_000 {
            return d
        }
        // Swimming
        if let d = workout.statistics(for: HKQuantityType(.distanceSwimming))?
            .sumQuantity()?.doubleValue(for: .meter()), d > 0, d.isFinite, d < 500_000 {
            return d
        }
        return nil
    }

    private func extractPaceAndSpeed(
        _ workout: HKWorkout,
        activityType: WorkoutActivityType
    ) -> (pace: Double?, speed: Double?) {
        // Running speed → convert to pace (sec/km)
        if let speedStats = workout.statistics(for: HKQuantityType(.runningSpeed)) {
            if let avgSpeed = speedStats.averageQuantity()?.doubleValue(for: .metersPerSecond()),
               avgSpeed > 0, avgSpeed.isFinite {
                let paceSecPerKm = 1000.0 / avgSpeed
                // Validate: 1:00/km to 60:00/km
                let validPace = (paceSecPerKm >= 60 && paceSecPerKm <= 3600) ? paceSecPerKm : nil
                return (pace: validPace, speed: avgSpeed)
            }
        }

        // Fallback: compute pace from distance and duration for distance-based activities
        if activityType.isDistanceBased,
           let distance = extractDistance(workout),
           distance > 0, workout.duration > 0 {
            let speedMs = distance / workout.duration
            let paceSecPerKm = 1000.0 / speedMs
            let validPace = (paceSecPerKm >= 60 && paceSecPerKm <= 3600) ? paceSecPerKm : nil
            return (pace: validPace, speed: speedMs)
        }

        return (nil, nil)
    }

    private func extractElevation(_ metadata: [String: Any]?) -> Double? {
        guard let quantity = metadata?[HKMetadataKeyElevationAscended] as? HKQuantity else {
            return nil
        }
        let value = quantity.doubleValue(for: .meter())
        guard value >= 0, value.isFinite, value < 10_000 else { return nil }
        return value
    }

    private func extractWeather(_ metadata: [String: Any]?) -> (Double?, Int?, Double?) {
        let temp: Double? = {
            guard let q = metadata?[HKMetadataKeyWeatherTemperature] as? HKQuantity else { return nil }
            let value = q.doubleValue(for: .degreeCelsius())
            guard value.isFinite, value > -100, value < 100 else { return nil }
            return value
        }()

        let condition = (metadata?[HKMetadataKeyWeatherCondition] as? NSNumber)?.intValue

        let humidity: Double? = {
            guard let q = metadata?[HKMetadataKeyWeatherHumidity] as? HKQuantity else { return nil }
            let value = q.doubleValue(for: .percent())
            guard value.isFinite, value >= 0, value <= 100 else { return nil }
            return value
        }()

        return (temp, condition, humidity)
    }

    /// Validates heart rate is within physiological range (20-300 bpm).
    private func validHR(_ value: Double?) -> Double? {
        guard let v = value, v >= 20, v <= 300, v.isFinite else { return nil }
        return v
    }
}

// MARK: - HKUnit helpers

private extension HKUnit {
    static var bpmUnit: HKUnit {
        .count().unitDivided(by: .minute())
    }

    static func metersPerSecond() -> HKUnit {
        .meter().unitDivided(by: .second())
    }
}
