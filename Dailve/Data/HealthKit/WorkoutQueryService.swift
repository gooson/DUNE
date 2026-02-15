import HealthKit

struct WorkoutQueryService: Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager = .shared) {
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
            WorkoutSummary(
                id: workout.uuid.uuidString,
                type: workoutTypeName(workout.workoutActivityType),
                duration: workout.duration,
                calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                distance: workout.totalDistance?.doubleValue(for: .meter()),
                date: workout.startDate
            )
        }
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
