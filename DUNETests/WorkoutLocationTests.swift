import Foundation
import HealthKit
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

    @Test("Archive retries temporary route failures while the detail screen retains a known place")
    func archiveRouteRetry() async throws {
        let place = try #require(WorkoutPlace(latitude: 1, longitude: 2, name: "Test", source: .manual))
        await #expect(throws: RouteFailure.self) {
            _ = try await WorkoutRouteQueryService.loadLocation(isIndoor: true, place: place, forArchive: true) {
                throw RouteFailure.unavailable
            }
        }
        let restricted = try await WorkoutRouteQueryService.loadLocation(isIndoor: true, place: place, forArchive: true) {
            throw HKError(.errorAuthorizationDenied)
        }
        #expect(restricted.place == place)
        #expect(restricted.route.isEmpty)
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

@Suite("HealthKit completed set backup")
@MainActor
struct HealthKitCompletedSetBackupTests {
    @Test("Failed HealthKit enrichment marks backup incomplete without repeating the write or erasing the original")
    func rejectedAttachmentIsVisible() async throws {
        let id = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: id))
        defer { defaults.removePersistentDomain(forName: id) }
        let place = try #require(WorkoutPlace(latitude: 37, longitude: 127, name: "Test", source: .manual))
        var attempts = 0
        try await WorkoutBackupWarning.attach(archive: nil, place: place) { metadata in
            attempts += 1
            #expect(WorkoutPlaceMetadata.place(from: metadata) == place)
            throw CocoaError(.fileWriteNoPermission)
        } markIncomplete: {
            WorkoutBackupWarning.record(in: defaults)
        }
        #expect(attempts == 1)
        #expect(defaults.bool(forKey: WorkoutBackupWarning.key))
        try await WorkoutBackupWarning.attach(archive: nil, place: place) { _ in
            attempts += 1
        } markIncomplete: { Issue.record("A valid attachment should succeed") }
        #expect(attempts == 2)
        #expect(defaults.bool(forKey: WorkoutBackupWarning.key))
    }

    @Test("An invalid set archive preserves an available workout place and flags the missing sets")
    func preservesValidPlace() async throws {
        let empty = WorkoutStrengthArchive(recordID: UUID(), exerciseDefinitionID: nil, sets: [])
        let place = try #require(WorkoutPlace(latitude: 37, longitude: 127, name: "Test", source: .manual))
        var written: [String: String] = [:]
        var incomplete = false
        try await WorkoutBackupWarning.attach(archive: empty, place: place) { metadata in
            written = metadata
        } markIncomplete: { incomplete = true }
        #expect(incomplete)
        #expect(written[WorkoutStrengthArchive.metadataKey] == nil)
        #expect(WorkoutPlaceMetadata.place(from: written) == place)
    }

    @Test("Only actual completed sets are restored with the same identifiers and measurements")
    func restoresCompletedSets() throws {
        let record = ExerciseRecord(date: .now, exerciseType: "Row", duration: 420, exerciseDefinitionID: "row")
        let set = WorkoutSet(
            setNumber: 2, weight: 35, reps: 10, duration: 45, distance: 0.2,
            intensity: 4, isCompleted: true, restDuration: 60, rpe: 7, plannedReps: 12, rpeSourceRaw: "user"
        )
        record.sets = [WorkoutSet(setNumber: 3, reps: 0), set]
        let archive = try #require(WorkoutStrengthArchive(record: record))
        let value = try #require(archive.encodedMetadata())
        let metadata = [WorkoutStrengthArchive.metadataKey: value]
        let restored = try #require(WorkoutStrengthArchive.read(from: metadata, isDUNEWorkout: true))
        #expect(restored.recordID == record.id)
        #expect(restored.exerciseDefinitionID == "row")
        let entries = restored.displaySets()
        #expect(entries.count == 1)
        let recovered = try #require(entries.first)
        #expect(recovered.id == set.id)
        #expect(recovered.isCompleted && recovered.setNumber == 2 && recovered.setTypeRaw == set.setTypeRaw)
        #expect(recovered.weight == 35 && recovered.reps == 10 && recovered.plannedReps == 12)
        #expect(recovered.rpe == 7 && recovered.rpeSourceRaw == "user")
        #expect(recovered.distance == 0.2 && recovered.intensity == 4 && recovered.duration == 45 && recovered.restDuration == 60)
        let summary = WorkoutSummary(
            id: UUID().uuidString, type: "Row", duration: 420, calories: nil, distance: nil, date: record.date,
            isFromThisApp: true, strengthArchive: restored
        )
        let item = ExerciseListItem.fromWorkoutSummary(summary)
        #expect(item.id == summary.id)
        #expect(item.exerciseDefinitionID == "row")
        #expect(item.completedSets.map(\.id) == [set.id])
        #expect(WorkoutStrengthArchive.read(from: metadata, isDUNEWorkout: false) == nil)
    }

    @Test("Older and malformed workout metadata never fabricate sets")
    func handlesLegacyMetadata() {
        #expect(WorkoutStrengthArchive.read(from: nil, isDUNEWorkout: true) == nil)
        #expect(WorkoutStrengthArchive.read(from: [WorkoutStrengthArchive.metadataKey: "{"], isDUNEWorkout: true) == nil)
        let record = ExerciseRecord(date: .now, exerciseType: "Walk", duration: 40)
        #expect(WorkoutStrengthArchive(record: record) == nil)
    }
}

#if targetEnvironment(simulator)
import HealthKit
import UIKit
import XCTest

@MainActor
final class HealthKitWorkoutRoundTripIntegrationTests: XCTestCase {
    /// Opt in by passing this destination's explicit UDID through TEST_RUNNER_DUNE_HEALTHKIT_QA_SIMULATOR_UDID.
    func testWorkoutSetsAndIndoorPlace() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let destination = environment["DUNE_HEALTHKIT_QA_SIMULATOR_UDID"], !destination.isEmpty,
              destination == environment["SIMULATOR_UDID"], UIDevice.current.userInterfaceIdiom == .phone else {
            throw XCTSkip("Requires an explicitly selected iPhone simulator.")
        }
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable(),
              store.authorizationStatus(for: .workoutType()) == .sharingAuthorized else {
            throw XCTSkip("The simulator has not granted DUNE permission to write workouts.")
        }
        guard SimulatorAdvancedMockDataProvider.current() == nil else {
            throw XCTSkip("Disable simulated athlete data before validating the real HealthKit store.")
        }

        let title = "DUNE-QA-" + UUID().uuidString
        let start = Date().addingTimeInterval(-180)
        let record = ExerciseRecord(date: start, exerciseType: title, duration: 120, exerciseDefinitionID: "qa-row")
        let set = WorkoutSet(setNumber: 1, weight: 15, reps: 8, isCompleted: true)
        record.sets = [set]
        let archive = try XCTUnwrap(WorkoutStrengthArchive(record: record))
        let place = try XCTUnwrap(WorkoutPlace(latitude: 0.125, longitude: 0.25, name: title, source: .manual))
        let input = WorkoutWriteInput(
            startDate: start, duration: 120, category: .strength, exerciseName: title,
            estimatedCalories: nil, isFromHealthKit: false, strengthArchive: archive,
            place: place, isIndoor: true
        )
        let savedID = try await WorkoutWriteService().saveWorkout(input)
        let savedUUID = try XCTUnwrap(UUID(uuidString: savedID))
        addTeardownBlock {
            let ownFixture = NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForObject(with: savedUUID),
                HKQuery.predicateForObjects(from: HKSource.default())
            ])
            let deleted = try await HKHealthStore().deleteObjects(of: .workoutType(), predicate: ownFixture)
            XCTAssertEqual(deleted, 1, "Expected to remove only the workout created by this run.")
        }

        let workouts = try await WorkoutQueryService(manager: .shared)
            .fetchWorkouts(start: start.addingTimeInterval(-1), end: Date())
        let matching = workouts.filter { $0.id == savedID }
        XCTAssertEqual(matching.count, 1)
        let readback = try XCTUnwrap(matching.first)
        XCTAssertEqual(readback.type, title)
        XCTAssertEqual(readback.isIndoor, true)
        let decoded = try XCTUnwrap(readback.strengthArchive)
        XCTAssertEqual(decoded.recordID, record.id)
        XCTAssertEqual(decoded.sets.map(\.id), [set.id])
        XCTAssertEqual(decoded.sets.first?.reps, 8)
        XCTAssertEqual(decoded.sets.first?.weight, 15)
        let location = try await WorkoutRouteQueryService().fetchLocation(workoutID: savedID)
        XCTAssertEqual(location.place, place)
        XCTAssertTrue(location.route.isEmpty)
    }
}
#endif
