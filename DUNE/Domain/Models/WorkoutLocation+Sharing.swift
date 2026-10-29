import Foundation

extension WorkoutLocationPayload {
    /// Returns a separate payload for sharing. Invalid trim values use 300 meters.
    /// Segment gaps contribute no distance, and a removed boundary remains a break in the published route.
    func shareLocation(showPlace: Bool, trimDistanceMeters: Double) -> WorkoutLocationPayload {
        guard showPlace else { return WorkoutLocationPayload(isIndoor: isIndoor) }
        guard route.count >= 2 else {
            return WorkoutLocationPayload(isIndoor: isIndoor, place: place)
        }

        let requestedTrim = trimDistanceMeters.isFinite && trimDistanceMeters >= 0
            ? trimDistanceMeters : 300
        let distances = zip(route, route.dropFirst()).map { previous, point in
            point.startsNewSegment ? 0 : previous.distance(to: point)
        }
        let totalDistance = distances.reduce(0, +)
        guard totalDistance.isFinite else {
            return WorkoutLocationPayload(isIndoor: isIndoor, place: place)
        }
        let trim = min(requestedTrim, totalDistance)
        guard totalDistance >= 2 * trim else {
            return WorkoutLocationPayload(isIndoor: isIndoor, place: place)
        }

        var cumulative = [Double](repeating: 0, count: route.count)
        for index in 1..<route.count {
            cumulative[index] = cumulative[index - 1] + distances[index - 1]
        }

        var retained: [WorkoutRoutePoint] = []
        retained.reserveCapacity(route.count)
        var previousIndex: Int?
        for index in route.indices {
            guard cumulative[index] >= trim,
                  totalDistance - cumulative[index] >= trim else { continue }
            var point = route[index]
            if let previousIndex {
                point.startsNewSegment = route[(previousIndex + 1)...index].contains { $0.startsNewSegment }
            } else {
                point.startsNewSegment = true
            }
            retained.append(point)
            previousIndex = index
        }

        return WorkoutLocationPayload(
            isIndoor: isIndoor,
            route: retained.count >= 2 ? retained : [],
            place: place
        )
    }
}
