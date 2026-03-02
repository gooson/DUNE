import HealthKit

/// Deletes HKWorkout from HealthKit by UUID.
/// Only works for workouts written by this app (same App Group).
struct WorkoutDeleteService: Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
    }

    /// Resolves the best available workout UUID to delete.
    /// Priority:
    /// 1) linked UUID from SwiftData record
    /// 2) closest app-family workout around record start time (fallback)
    func resolveDeletionTargetUUID(
        linkedUUID: String?,
        fallbackStartDate: Date,
        preferredActivityType: WorkoutActivityType?
    ) async throws -> String? {
        if let linked = validUUIDString(linkedUUID) {
            return linked
        }
        return try await findClosestWorkoutUUID(
            around: fallbackStartDate,
            preferredActivityType: preferredActivityType
        )
    }

    /// Delete the HKWorkout matching the given UUID string.
    /// Silently succeeds if workout not found or already deleted.
    func deleteWorkout(uuid uuidString: String) async throws {
        guard !uuidString.isEmpty,
              let uuid = UUID(uuidString: uuidString) else { return }

        let store = await manager.healthStore

        let predicate = HKQuery.predicateForObject(with: uuid)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [],
            limit: 1
        )

        let workouts = try await manager.execute(descriptor)
        guard let workout = workouts.first else { return }

        try await store.delete(workout)
    }

    private func validUUIDString(_ value: String?) -> String? {
        guard let value, !value.isEmpty, UUID(uuidString: value) != nil else { return nil }
        return value
    }

    private func findClosestWorkoutUUID(
        around startDate: Date,
        preferredActivityType: WorkoutActivityType?
    ) async throws -> String? {
        let searchWindow: TimeInterval = 5 * 60
        let maxMatchDelta: TimeInterval = 2 * 60

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate.addingTimeInterval(-searchWindow),
            end: startDate.addingTimeInterval(searchWindow),
            options: .strictStartDate
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: 50
        )

        let workouts = try await manager.execute(descriptor)
        guard !workouts.isEmpty else { return nil }

        // Prefer workouts written by this app family (iOS + watch companion).
        let appFamilyWorkouts = workouts.filter { workout in
            WorkoutSourceClassifier.isFromAppFamily(
                sourceBundleIdentifier: workout.sourceRevision.source.bundleIdentifier
            )
        }
        guard !appFamilyWorkouts.isEmpty else { return nil }
        let sourceScoped = appFamilyWorkouts

        // Without an activity hint, avoid ambiguous fallback deletes.
        let hasTypeHint: Bool = {
            guard let preferredActivityType else { return false }
            return preferredActivityType != .other
        }()
        if !hasTypeHint, sourceScoped.count > 1 {
            return nil
        }

        let typeScoped: [HKWorkout]
        if let preferredActivityType, hasTypeHint {
            let matchedByType = sourceScoped.filter { workout in
                WorkoutActivityType(healthKit: workout.workoutActivityType) == preferredActivityType
            }
            typeScoped = matchedByType.isEmpty ? sourceScoped : matchedByType
        } else {
            typeScoped = sourceScoped
        }

        guard let closest = typeScoped.min(by: { lhs, rhs in
            abs(lhs.startDate.timeIntervalSince(startDate)) < abs(rhs.startDate.timeIntervalSince(startDate))
        }) else {
            return nil
        }

        let delta = abs(closest.startDate.timeIntervalSince(startDate))
        guard delta <= maxMatchDelta else { return nil }
        return closest.uuid.uuidString
    }
}
