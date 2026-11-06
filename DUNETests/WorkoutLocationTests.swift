import Foundation
import Testing
@testable import DUNE

@Suite("WorkoutLocation")
struct WorkoutLocationTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private enum RouteFailure: Error { case unavailable }

    @Test("A route failure preserves an indoor place already loaded from HealthKit")
    func routeFailurePreservesPlace() async throws {
        let place = try #require(WorkoutPlace(latitude: 37.54, longitude: 127.04, name: "", source: .gps))
        let result = try await WorkoutRouteQueryService.loadLocation(isIndoor: true, place: place) {
            throw RouteFailure.unavailable
        }
        #expect(result.isIndoor == true)
        #expect(result.place == place)
        #expect(result.route.isEmpty)
    }

    @Test("A route failure without a place remains an error")
    func routeFailureWithoutPlace() async {
        do {
            _ = try await WorkoutRouteQueryService.loadLocation(isIndoor: false, place: nil) {
                throw RouteFailure.unavailable
            }
            Issue.record("Missing route and place must preserve the loading error")
        } catch {
            #expect(error is RouteFailure)
        }
    }

    @Test("Cancelling route loading never presents a place from an obsolete request")
    func routeCancellation() async throws {
        let place = try #require(WorkoutPlace(latitude: 37.54, longitude: 127.04, name: "", source: .gps))
        do {
            _ = try await WorkoutRouteQueryService.loadLocation(isIndoor: true, place: place) {
                throw CancellationError()
            }
            Issue.record("Cancellation must propagate even when place metadata exists")
        } catch {
            #expect(error is CancellationError)
        }
    }

    @Test("Successful imported indoor routes and place metadata are both retained")
    func routeAndPlaceSuccess() async throws {
        let place = try #require(WorkoutPlace(latitude: 37.54, longitude: 127.04, name: "", source: .gps))
        let point = try #require(WorkoutRoutePoint(latitude: 37.54, longitude: 127.04, timestamp: date, startsNewSegment: true))
        let result = try await WorkoutRouteQueryService.loadLocation(isIndoor: true, place: place) { [point] }
        #expect(result.place == place)
        #expect(result.route == [point])
    }

    @Test("Watch indoor place metadata round trips independently of route data")
    func watchPlaceMetadata() throws {
        let place = try #require(WorkoutPlace(latitude: 37.54, longitude: 127.04, name: "", source: .gps))
        let value = try #require(WorkoutPlaceMetadata.encodedValue(for: place))
        #expect(WorkoutPlaceMetadata.place(from: [WorkoutPlaceMetadata.key: value]) == place)
        #expect(place.displayName == String(localized: "Workout location"))
        let named = try #require(WorkoutPlace(latitude: 37, longitude: 127, name: "Gym", source: .manual))
        #expect(named.displayName == "Gym")
        #expect(WorkoutPlaceMetadata.place(from: nil) == nil)
        #expect(WorkoutPlaceMetadata.place(from: [WorkoutPlaceMetadata.key: "invalid"]) == nil)
        #expect(WorkoutPlaceMetadata.place(from: [WorkoutPlaceMetadata.key: String(repeating: "x", count: 2_001)]) == nil)
        let invalid = "{\"latitude\":91,\"longitude\":127,\"name\":\"\",\"source\":\"gps\"}"
        #expect(WorkoutPlaceMetadata.place(from: [WorkoutPlaceMetadata.key: invalid]) == nil)
    }

    @Test("Rejects non-finite, unbounded and inaccurate location inputs")
    func invalidPoints() {
        for latitude in [Double.nan, .infinity, -91, 91] {
            #expect(WorkoutRoutePoint(latitude: latitude, longitude: 127, timestamp: date) == nil)
        }
        #expect(WorkoutRoutePoint(latitude: 37, longitude: 181, timestamp: date) == nil)
        #expect(WorkoutRoutePoint(latitude: 37, longitude: 127, timestamp: .distantFuture) == nil)
        #expect(WorkoutRoutePoint(latitude: 37, longitude: 127, timestamp: date, altitude: .nan) == nil)
        #expect(WorkoutRoutePoint(latitude: 37, longitude: 127, timestamp: date, horizontalAccuracy: -1) == nil)
        #expect(WorkoutPlace(latitude: .infinity, longitude: 0, name: "Gym", source: .manual) == nil)
    }

    @Test("Route gaps, jumps and out-of-order samples break the next line")
    func discontinuities() throws {
        let offsets: [(Double, Double)] = [(0, 0), (1, 0.00001), (90, 0.00002), (91, 1), (90, 1), (92, 1.00001)]
        let points = try offsets.map { time, longitude in
            try #require(WorkoutRoutePoint(latitude: 37, longitude: 127 + longitude,
                                           timestamp: date.addingTimeInterval(time)))
        }
        let route = WorkoutLocationPayload.normalizedRoute(points)
        #expect(route.count == 5)
        #expect(route.map(\.startsNewSegment) == [true, false, true, true, true])
    }

    @Test("Downsampling preserves endpoints and boundaries removed between samples")
    func downsampling() throws {
        let points = try (0..<10_000).map { index in
            try #require(WorkoutRoutePoint(latitude: 37, longitude: 127 + Double(index) * 0.000001,
                                           timestamp: date.addingTimeInterval(Double(index)),
                                           altitude: 10, horizontalAccuracy: 5,
                                           startsNewSegment: index == 5))
        }
        let reduced = WorkoutLocationPayload.normalizedRoute(points, limit: 3)
        #expect(reduced.map(\.timestamp) == [points[0].timestamp, points[4999].timestamp, points[9999].timestamp])
        #expect(reduced[1].startsNewSegment)
        let payload = WorkoutLocationPayload(route: points)
        #expect(payload.route.count == WorkoutLocationPayload.maxRoutePoints)
        #expect(try JSONEncoder().encode(payload).count < 1_000_000)
        #expect(WorkoutLocationPayload.normalizedRoute(points) == payload.route)
    }

    @Test("Indoor metadata preserves an actually recorded imported route and place")
    func indoorPlace() throws {
        let place = try #require(WorkoutPlace(latitude: 37, longitude: 127, name: " Gym ", source: .manual))
        let point = try #require(WorkoutRoutePoint(latitude: 37, longitude: 127, timestamp: date))
        let payload = WorkoutLocationPayload(isIndoor: true, route: [point], place: place)
        #expect(payload.route.count == 1)
        #expect(payload.place?.name == "Gym")
        #expect(payload.place?.source == .manual)
        let decoded = try JSONDecoder().decode(WorkoutLocationPayload.self, from: JSONEncoder().encode(payload))
        #expect(decoded == payload)
    }

    @Test("Oversized and corrupt stored payloads safely remain unavailable")
    func corruptPayload() {
        let record = WorkoutLocationRecord(payload: WorkoutLocationPayload(isIndoor: false))
        record.payloadData = Data(repeating: 0, count: 1_000_001)
        #expect(record.payload == nil)
        record.payloadData = Data("invalid json".utf8)
        #expect(record.payload == nil)
    }
}
