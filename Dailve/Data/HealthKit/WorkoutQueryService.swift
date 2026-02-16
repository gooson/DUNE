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

    private func toSummary(_ workout: HKWorkout) -> WorkoutSummary {
        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
        let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .meter())

        return WorkoutSummary(
            id: workout.uuid.uuidString,
            type: workoutTypeName(workout.workoutActivityType),
            duration: workout.duration,
            calories: calories,
            distance: distance,
            date: workout.startDate
        )
    }

    private func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .yoga: "Yoga"
        case .functionalStrengthTraining: "Strength"
        case .highIntensityIntervalTraining: "HIIT"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .coreTraining: "Core"
        case .flexibility: "Flexibility"
        case .dance: "Dance"
        case .pilates: "Pilates"
        default: "Workout"
        }
    }
}
