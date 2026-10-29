import Foundation
import HealthKit

protocol WorkoutRouteQuerying: Sendable {
    func fetchRoute(workoutID: String) async throws -> [WorkoutRoutePoint]
}

/// Reads both iPhone and imported Apple Watch routes; absent results do not imply read permission.
struct WorkoutRouteQueryService: WorkoutRouteQuerying, Sendable {
    private let manager: HealthKitManager

    init(manager: HealthKitManager = .shared) { self.manager = manager }

    func fetchRoute(workoutID: String) async throws -> [WorkoutRoutePoint] {
        guard let id = UUID(uuidString: workoutID) else { return [] }
        guard manager.isAvailable else { return [] }
        try Task.checkCancellation()
        let workoutQuery = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForObject(with: id))],
            sortDescriptors: [], limit: 1
        )
        guard let workout = try await manager.execute(workoutQuery).first else { return [] }
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
