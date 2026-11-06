import Foundation
import HealthKit
import OSLog

/// Reads both iPhone and imported Apple Watch routes; absent results do not imply read permission.
struct WorkoutRouteQueryService: Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager = .shared) { self.manager = manager }

    func fetchLocation(workoutID: String) async throws -> WorkoutLocationPayload {
        guard let id = UUID(uuidString: workoutID) else { return WorkoutLocationPayload() }
        guard manager.isAvailable else { return WorkoutLocationPayload() }
        try Task.checkCancellation()
        let workoutQuery = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForObject(with: id))],
            sortDescriptors: [], limit: 1
        )
        guard let workout = try await manager.execute(workoutQuery).first else { return WorkoutLocationPayload() }
        return try await Self.loadLocation(
            isIndoor: workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool,
            place: WorkoutPlaceMetadata.place(from: workout.metadata)
        ) {
            try await fetchRoutePoints(for: workout)
        }
    }

    /// A failed optional route must not hide a place already recorded with the workout.
    static func loadLocation(
        isIndoor: Bool?, place: WorkoutPlace?,
        routeLoader: @Sendable () async throws -> [WorkoutRoutePoint]
    ) async throws -> WorkoutLocationPayload {
        do {
            let route = try await routeLoader()
            try Task.checkCancellation()
            return WorkoutLocationPayload(isIndoor: isIndoor, route: route, place: place)
        } catch {
            if error is CancellationError { throw error }
            try Task.checkCancellation()
            guard let place else { throw error }
            AppLogger.healthKit.warning("Could not load recorded route; preserving workout place: \(error.localizedDescription, privacy: .private)")
            return WorkoutLocationPayload(isIndoor: isIndoor, place: place)
        }
    }

    private func fetchRoutePoints(for workout: HKWorkout) async throws -> [WorkoutRoutePoint] {
        let routeQuery = HKSampleQueryDescriptor(
            predicates: [.workoutRoute(HKQuery.predicateForObjects(from: workout))],
            sortDescriptors: [SortDescriptor(\HKWorkoutRoute.startDate)]
        )
        let routes = try await manager.execute(routeQuery)
        let store = await manager.healthStore
        var points: [WorkoutRoutePoint] = []
        for route in routes {
            var newSegment = true
            for try await location in HKWorkoutRouteQueryDescriptor(route).results(for: store) {
                try Task.checkCancellation()
                guard location.timestamp >= workout.startDate, location.timestamp <= workout.endDate,
                      let point = WorkoutRoutePoint(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        timestamp: location.timestamp,
                        altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
                        horizontalAccuracy: location.horizontalAccuracy,
                        startsNewSegment: newSegment
                      ) else { newSegment = true; continue }
                points.append(point)
                newSegment = false
                if points.count > WorkoutLocationPayload.maxRoutePoints {
                    points = WorkoutLocationPayload.normalizedRoute(
                        points, limit: WorkoutLocationPayload.maxRoutePoints / 2
                    )
                }
            }
        }
        return WorkoutLocationPayload.normalizedRoute(points)
    }
}
