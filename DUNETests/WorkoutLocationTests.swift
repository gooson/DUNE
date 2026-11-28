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

#if targetEnvironment(simulator) && os(iOS)
import CloudKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class LegacyWorkoutRecoveryPresentationTests: XCTestCase {
    func testImportedWorkoutSetAndPlaceCountsInSettings() async throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("iPhone settings capture") }
        let schema = Schema([ExerciseRecord.self, WorkoutSet.self, WorkoutLocationRecord.self])
        let storage = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: storage)
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let workouts = (0..<2).map { _ in
            let record = CKRecord(recordType: "CD_ExerciseRecord")
            record["CD_id"] = UUID().uuidString
            record["CD_date"] = stamp
            record["CD_createdAt"] = stamp
            record["CD_exerciseType"] = "Fixture"
            record["CD_duration"] = 60
            return record
        }
        let sets = (0..<3).map { index in
            let set = CKRecord(recordType: "CD_WorkoutSet")
            set["CD_id"] = UUID().uuidString
            set["CD_setNumber"] = NSNumber(value: index + 1)
            set["CD_exerciseRecord"] = workouts[index % workouts.count].recordID.recordName
            return set
        }
        let location = CKRecord(recordType: "CD_WorkoutLocationRecord")
        location["CD_id"] = UUID().uuidString
        location["CD_localRecordID"] = workouts[0]["CD_id"]
        location["CD_updatedAt"] = stamp
        let place = try XCTUnwrap(WorkoutPlace(latitude: 0.125, longitude: 0.25, name: "Fixture", source: .manual))
        location["CD_payloadData"] = try JSONEncoder().encode(WorkoutLocationPayload(isIndoor: true, place: place))
        let records = workouts + sets + [location]

        let recovery = SettingsWorkoutRecovery()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        defer {
            window.isHidden = true
            previous?.makeKey()
        }
        let screen = NavigationStack {
            SettingsDetailView(route: .privacy, recovery: recovery) { _ in }
                .navigationTitle("Data & Privacy")
        }
        .modelContainer(container)
        window.rootViewController = UIHostingController(rootView: screen)
        window.makeKeyAndVisible()

        await recovery.restore { try LegacyWorkoutRecovery.importRecords(records, into: container) }
        let workoutCount = 2, setCount = 3
        let summary = String(localized: "Restored \(workoutCount) workouts and \(setCount) sets to this device.")
        let label = String(localized: "Workout location")
        XCTAssertEqual(recovery.message, summary + "\n" + label + " · 1")
        XCTAssertFalse(recovery.isRestoring)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseRecord>()), workoutCount)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSet>()), setCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutLocationRecord>()).first?.payload?.place, place)

        window.layoutIfNeeded()
        await Task.yield()
        window.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
        attachment.name = "S01-legacy-restored-workouts-sets-place"
        attachment.lifetime = .keepAlways
        add(attachment)

        await recovery.restore { try LegacyWorkoutRecovery.importRecords(records, into: container) }
        let zero = 0
        XCTAssertEqual(recovery.message, String(localized: "Restored \(zero) workouts and \(zero) sets to this device."))
    }
}
#endif

#if targetEnvironment(simulator) && os(iOS)
@MainActor
final class BackupFileWorkflowTests: XCTestCase {
    func testRecordsStayLocalAndRequireOwnershipToCombine() async throws {
        let schema = AppSchema.currentSchema
        func device() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: ModelConfiguration(
                schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
            ))
        }
        let source = try device(), destination = try device()
        let suites = (UUID().uuidString, UUID().uuidString)
        let original = try XCTUnwrap(UserDefaults(suiteName: suites.0))
        let restored = try XCTUnwrap(UserDefaults(suiteName: suites.1))
        defer {
            original.removePersistentDomain(forName: suites.0)
            restored.removePersistentDomain(forName: suites.1)
        }
        let sample = ExerciseRecord(exerciseType: "Fixture", duration: 60)
        source.mainContext.insert(sample)
        try source.mainContext.save()
        let flow = BackupFileWorkflow()
        flow.startExport(.records)
        await flow.saveRecords(context: source.mainContext, defaults: original)
        XCTAssertNil(flow.savedFilename)
        let key = flow.exportKey
        flow.savedKey = true
        let blocked = await flow.prepareSettingsExport(defaults: original)
        XCTAssertFalse(blocked)
        XCTAssertNil(flow.document)
        await flow.saveRecords(context: source.mainContext, defaults: original)
        let filename = try XCTUnwrap(flow.savedFilename)
        let file = try XCTUnwrap(LocalRecoveryFiles.archives().first { $0.lastPathComponent == filename })
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual(flow.step, .home)
        XCTAssertTrue(flow.exportKey.isEmpty)
        let backupDirectory = file.deletingLastPathComponent()
        XCTAssertEqual(try backupDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        await flow.selectFile(.success(file))
        XCTAssertEqual(flow.step, .restoreKey)
        flow.inputKey = EncryptedRecoveryArchive.makeRecoveryKey()
        await flow.restore(context: destination.mainContext, defaults: restored)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<ExerciseRecord>()), 0)
        XCTAssertEqual(flow.step, .restoreKey)
        XCTAssertEqual(flow.message.map { String(localized: $0) },
                       String(localized: "Couldn’t restore this file. Check the recovery key and backup file."))
        let existing = ExerciseRecord(exerciseType: "Existing fixture", duration: 30)
        destination.mainContext.insert(existing)
        try destination.mainContext.save()
        flow.inputKey = key
        await flow.restore(context: destination.mainContext, defaults: restored)
        XCTAssertTrue(flow.canCombine)
        XCTAssertFalse(flow.confirmedOwnership)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<ExerciseRecord>()), 1)
        flow.confirmedOwnership = true
        flow.inputKey = key
        await flow.restore(context: destination.mainContext, defaults: restored)
        XCTAssertEqual(flow.step, .home)
        XCTAssertTrue(flow.inputKey.isEmpty)
        XCTAssertEqual(flow.message.map { String(localized: $0) }, String(localized: "Backup file restored to this device."))
        XCTAssertEqual(flow.restoredRecords?.workoutCount, 1)
        XCTAssertEqual(flow.restoredRecords?.setCount, 0)
        XCTAssertEqual(flow.restoredRecords?.insertedRowCount, 1)
        XCTAssertEqual(Set(try destination.mainContext.fetch(FetchDescriptor<ExerciseRecord>()).map(\.id)), [existing.id, sample.id])
    }

    func testPortableSettingsExportAndRepeatedImport() async throws {
        let schema = AppSchema.currentSchema
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        ))
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "Fixture.dunebackup")
        let suites = (UUID().uuidString, UUID().uuidString)
        let source = try XCTUnwrap(UserDefaults(suiteName: suites.0))
        let target = try XCTUnwrap(UserDefaults(suiteName: suites.1))
        defer {
            source.removePersistentDomain(forName: suites.0)
            target.removePersistentDomain(forName: suites.1)
        }
        source.set("lb", forKey: WeightUnit.storageKey)
        let flow = BackupFileWorkflow()
        flow.startExport(.settings)
        let blocked = await flow.prepareSettingsExport(defaults: source)
        XCTAssertFalse(blocked)
        let key = flow.exportKey
        flow.savedKey = true
        let ready = await flow.prepareSettingsExport(defaults: source)
        XCTAssertTrue(ready)
        XCTAssertNil(flow.message)
        flow.finishedExport(.failure(CocoaError(.userCancelled)))
        XCTAssertNil(flow.message)
        let retry = await flow.prepareSettingsExport(defaults: source)
        XCTAssertTrue(retry)
        let encrypted = try XCTUnwrap(flow.document?.ciphertext)
        try encrypted.write(to: file, options: .atomic)
        flow.finishedExport(.success(file))
        XCTAssertEqual(flow.message.map { String(localized: $0) }, String(localized: "Encrypted backup file saved."))
        for _ in 0..<2 {
            await flow.selectFile(.success(file))
            flow.inputKey = key
            await flow.restore(context: container.mainContext, defaults: target)
            XCTAssertEqual(flow.step, .home)
            XCTAssertEqual(flow.message.map { String(localized: $0) }, String(localized: "Appearance and unit settings restored."))
            XCTAssertEqual(target.string(forKey: WeightUnit.storageKey), "lb")
        }
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ExerciseRecord>()), 0)

        // Public fixture-only key, never used for an app user's backup.
        let publicFixtureKey = Data((0..<32).map(UInt8.init)).base64EncodedString()
        let profile = try EncryptedRecoveryArchive.open(encrypted, recoveryKey: key)
        XCTAssertEqual(profile, try AppOwnedBackup.encodeDriveSettings(defaults: source))
        let fixture = try EncryptedRecoveryArchive.seal(profile, recoveryKey: publicFixtureKey)
        let attachment = XCTAttachment(data: fixture, uniformTypeIdentifier: UTType.duneEncryptedBackup.identifier)
        attachment.name = "Synthetic-DUNE-Drive-Settings.dunebackup"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
