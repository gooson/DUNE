import Foundation

/// Validated coordinate sample. Segment boundaries must survive filtering and downsampling.
struct WorkoutRoutePoint: Codable, Sendable, Hashable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let altitude: Double?
    let horizontalAccuracy: Double?
    var startsNewSegment: Bool

    init?(
        latitude: Double, longitude: Double, timestamp: Date,
        altitude: Double? = nil, horizontalAccuracy: Double? = nil,
        startsNewSegment: Bool = false
    ) {
        guard Self.validCoordinate(latitude: latitude, longitude: longitude),
              timestamp.timeIntervalSinceReferenceDate.isFinite,
              timestamp >= Date(timeIntervalSince1970: 0),
              timestamp <= Date(timeIntervalSince1970: 7_258_118_400),
              altitude.map({ $0.isFinite && (-12_000...100_000).contains($0) }) ?? true,
              horizontalAccuracy.map({ $0.isFinite && (0...100).contains($0) }) ?? true else { return nil }
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.startsNewSegment = startsNewSegment
    }

    static func validCoordinate(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    var isValid: Bool {
        Self(latitude: latitude, longitude: longitude, timestamp: timestamp,
             altitude: altitude, horizontalAccuracy: horizontalAccuracy) != nil
    }

    func distance(to other: Self) -> Double {
        let radians = Double.pi / 180
        let latDelta = (other.latitude - latitude) * radians
        let lonDelta = (other.longitude - longitude) * radians
        let a = pow(sin(latDelta / 2), 2)
            + cos(latitude * radians) * cos(other.latitude * radians) * pow(sin(lonDelta / 2), 2)
        return 6_371_000 * 2 * asin(sqrt(min(1, max(0, a))))
    }
}

struct WorkoutPlace: Codable, Sendable, Hashable {
    // Persisted raw values are a storage contract; do not rename.
    enum Source: String, Codable, Sendable { case manual, gps, healthKit }
    let latitude: Double
    let longitude: Double
    let name: String
    let source: Source

    init?(latitude: Double, longitude: Double, name: String, source: Source) {
        guard WorkoutRoutePoint.validCoordinate(latitude: latitude, longitude: longitude) else { return nil }
        self.latitude = latitude
        self.longitude = longitude
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        self.source = source
    }
}

struct WorkoutLocationPayload: Codable, Sendable, Hashable {
    /// Keeps JSON comfortably below CloudKit's 1 MB record limit, including optional fields.
    static let maxRoutePoints = 4_000
    var isIndoor: Bool?
    var route: [WorkoutRoutePoint]
    var place: WorkoutPlace?

    init(isIndoor: Bool? = nil, route: [WorkoutRoutePoint] = [], place: WorkoutPlace? = nil) {
        self.isIndoor = isIndoor
        // Indoor metadata describes the workout, not whether an actual route can exist.
        // Indoor sessions capture a place pin, while imported recorded paths survive.
        self.route = Self.normalizedRoute(route)
        self.place = place.flatMap {
            WorkoutPlace(latitude: $0.latitude, longitude: $0.longitude, name: $0.name, source: $0.source)
        }
    }

    static func normalizedRoute(_ points: [WorkoutRoutePoint], limit: Int = maxRoutePoints) -> [WorkoutRoutePoint] {
        guard limit >= 2 else { return [] }
        var valid: [WorkoutRoutePoint] = []
        var pendingBreak = true
        for var point in points {
            guard point.isValid else { pendingBreak = true; continue }
            if let last = valid.last {
                let gap = point.timestamp.timeIntervalSince(last.timestamp)
                guard gap > 0 else { pendingBreak = true; continue }
                let distance = last.distance(to: point)
                pendingBreak = pendingBreak || gap > 60 || distance > 2_000 || distance / gap > 100
            }
            point.startsNewSegment = point.startsNewSegment || pendingBreak
            valid.append(point)
            pendingBreak = false
        }
        guard valid.count > limit else { return valid }
        var result: [WorkoutRoutePoint] = []
        result.reserveCapacity(limit)
        var previousIndex = -1
        for index in 0..<limit {
            let sourceIndex = index * (valid.count - 1) / (limit - 1)
            var point = valid[sourceIndex]
            // A removed boundary still breaks the displayed line at the next retained point.
            point.startsNewSegment = valid[(previousIndex + 1)...sourceIndex].contains { $0.startsNewSegment }
            result.append(point)
            previousIndex = sourceIndex
        }
        return result
    }
}

/// Shared Watch/iPhone storage contract for an observed workout place, separate from a route.
enum WorkoutPlaceMetadata {
    static let key = "com.dune.workout.place"

    static func encodedValue(for place: WorkoutPlace) -> String? {
        // Encoding this bounded value has no recoverable caller action.
        guard let data = try? JSONEncoder().encode(place) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func place(from metadata: [String: Any]?) -> WorkoutPlace? {
        guard let value = metadata?[key] as? String, value.utf8.count <= 2_000,
              let data = value.data(using: .utf8),
              // Optional enrichment from older or malformed metadata can be absent.
              let decoded = try? JSONDecoder().decode(WorkoutPlace.self, from: data) else { return nil }
        return WorkoutPlace(latitude: decoded.latitude, longitude: decoded.longitude,
                            name: decoded.name, source: decoded.source)
    }
}
