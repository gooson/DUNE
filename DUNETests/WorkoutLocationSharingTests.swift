import Foundation
import Testing
@testable import DUNE

@Suite("WorkoutLocationPayload sharing")
struct WorkoutLocationSharingTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Hidden place removes route, coordinates, and name while preserving indoor state")
    func hiddenPlace() throws {
        let original = WorkoutLocationPayload(
            isIndoor: false,
            route: [point(0, at: 0), point(0.001, at: 10)],
            place: try #require(WorkoutPlace(latitude: 0, longitude: 0, name: "Home", source: .manual))
        )

        let shared = original.shareLocation(showPlace: false, trimDistanceMeters: 0)

        #expect(shared.isIndoor == false)
        #expect(shared.route.isEmpty)
        #expect(shared.place == nil)
        #expect(original.route.count == 2)
        #expect(original.place?.name == "Home")
    }

    @Test("A short route is omitted but an explicitly shared place remains")
    func shortRoute() throws {
        let place = try #require(WorkoutPlace(latitude: 0, longitude: 0, name: "Park", source: .manual))
        let route = [point(0, at: 0), point(0.001, at: 10)]
        let original = WorkoutLocationPayload(route: route, place: place)
        let originalRoute = original.route

        let shared = original.shareLocation(showPlace: true, trimDistanceMeters: 100)

        #expect(shared.route.isEmpty)
        #expect(shared.place == place)
        #expect(original.route == originalRoute)
        #expect(WorkoutLocationPayload(route: [route[0]]).shareLocation(showPlace: true, trimDistanceMeters: 0).route.isEmpty)
    }

    @Test("Both route endpoints are trimmed by recorded geometric distance")
    func endpointTrimming() {
        let route = (0...10).map { point(Double($0) * 0.001, at: $0 * 10) }
        let original = WorkoutLocationPayload(route: route)
        let originalRoute = original.route

        let shared = original.shareLocation(showPlace: true, trimDistanceMeters: 300)

        #expect(shared.route.count == 5)
        #expect(shared.route.first?.longitude == 0.003)
        #expect(shared.route.last?.longitude == 0.007)
        #expect(shared.route.first?.startsNewSegment == true)
        #expect(original.route == originalRoute)
    }

    @Test("Gaps add no travelled distance and retained segment starts remain marked")
    func segmentedRoute() {
        let first = (0...4).map { point(Double($0) * 0.001, at: $0 * 10) }
        let second = (0...4).map { point(10 + Double($0) * 0.001, at: 100 + $0 * 10) }
        let original = WorkoutLocationPayload(route: first + second)

        let shared = original.shareLocation(showPlace: true, trimDistanceMeters: 150)
        let segmentStarts = shared.route.filter(\.startsNewSegment)

        #expect(shared.route.first?.longitude == 0.002)
        #expect(segmentStarts.count == 2)
        #expect(segmentStarts.dropFirst().first?.longitude == 10)

        let tooShort = WorkoutLocationPayload(route: [first[0], first[1], second[0], second[1]])
        #expect(tooShort.shareLocation(showPlace: true, trimDistanceMeters: 150).route.isEmpty)
    }

    @Test("Invalid trim uses the documented 300 meter fallback")
    func invalidTrim() {
        let original = WorkoutLocationPayload(route: (0...10).map { point(Double($0) * 0.001, at: $0 * 10) })
        let expected = original.shareLocation(showPlace: true, trimDistanceMeters: 300)

        #expect(original.shareLocation(showPlace: true, trimDistanceMeters: -.infinity) == expected)
        #expect(original.shareLocation(showPlace: true, trimDistanceMeters: .nan) == expected)
        #expect(original.shareLocation(showPlace: true, trimDistanceMeters: -1) == expected)
    }

    @Test("No trim keeps the exact route and an absent place stays absent")
    func exactNoTrim() {
        let original = WorkoutLocationPayload(
            isIndoor: false,
            route: [point(0, at: 0), point(0.001, at: 10), point(0.002, at: 20)]
        )

        let shared = original.shareLocation(showPlace: true, trimDistanceMeters: 0)

        #expect(shared.route == original.route)
        #expect(shared.place == nil)
        #expect(shared.isIndoor == original.isIndoor)
    }

    private func point(_ longitude: Double, at seconds: Int) -> WorkoutRoutePoint {
        // All fixture coordinates and timestamps satisfy the model's validation.
        try! #require(WorkoutRoutePoint(latitude: 0, longitude: longitude,
                                        timestamp: start.addingTimeInterval(Double(seconds))))
    }
}
