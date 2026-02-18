import HealthKit

/// Deletes HKWorkout from HealthKit by UUID.
/// Only works for workouts written by this app (same App Group).
struct WorkoutDeleteService: Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager) {
        self.manager = manager
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
}
