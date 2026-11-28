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

#if targetEnvironment(simulator) && os(iOS)
import CryptoKit

@MainActor
final class HealthKitAndFileArrivalTests: XCTestCase {
    private struct Fixture {
        let workout: HKWorkout
        let recordID: UUID
        let sets: [UUID]
        let place: WorkoutPlace
        let portraitID: UUID
        let photoHash: Data
        let rewards: [WorkoutRewardEvent]
        let key: String
        let url: URL
    }

    /// Local QA attachments for a clean replacement-device receiver. No HealthKit sample is saved.
    func testExportSyntheticReplacementDeviceFixture() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try makeSource(in: source, archiveDirectory: root)
        try FileManager.default.removeItem(at: source)
        struct Manifest: Encodable {
            let format = "DUNE-synthetic-replacement-v1"
            let workoutID: UUID
            let recordID: UUID
            let date: Date
            let sets: [UUID]
            let reps = [8, 6]
            let weights = [15.0, 20.0]
            let place: WorkoutPlace
            let portraitID: UUID
            let photoHash: Data
            let prType = PersonalRecordType.longestDuration
            let prValue = 120.0
            let rewards: [WorkoutRewardEvent]
            let fileHash: Data
            let key: String
        }
        let ciphertext = try Data(contentsOf: fixture.url)
        let manifest = Manifest(workoutID: fixture.workout.uuid, recordID: fixture.recordID,
                                date: fixture.workout.startDate, sets: fixture.sets, place: fixture.place,
                                portraitID: fixture.portraitID, photoHash: fixture.photoHash, rewards: fixture.rewards,
                                fileHash: Data(SHA256.hash(data: ciphertext)), key: fixture.key)
        for (name, bytes, type) in [
            ("safe-fixture.dunebackup", ciphertext, UTType.data),
            ("safe-manifest.json", try JSONEncoder().encode(manifest), UTType.json)
        ] {
            let file = XCTAttachment(data: bytes, uniformTypeIdentifier: type.identifier)
            file.name = name
            file.lifetime = .keepAlways
            add(file)
        }
    }

    func testHealthKitFirstThenEncryptedFile() async throws {
        try await verifyArrival(healthFirst: true)
    }

    func testEncryptedFileFirstThenHealthKit() async throws {
        try await verifyArrival(healthFirst: false)
    }

    func testEncryptedFilePreservesLocalWorkoutAfterHealthKitDeletion() async throws {
        try requireAuthorizedSimulator()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try makeSource(in: source, archiveDirectory: root)
        try await HKHealthStore().save(fixture.workout)
        let uuid = fixture.workout.uuid
        addTeardownBlock {
            let predicate = HKSamplePredicate.workout(Self.ownedWorkoutPredicate(uuid))
            let query = HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: [], limit: 1)
            let remaining = try await query.result(for: HKHealthStore())
            if !remaining.isEmpty {
                let cleaned = try await Self.removeOwnedWorkout(uuid)
                XCTAssertEqual(cleaned, 1)
            }
        }
        let present = try await readWorkout(fixture)
        XCTAssertEqual(present.map(\.id), [uuid.uuidString])
        try FileManager.default.removeItem(at: source)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        let deleted = try await Self.removeOwnedWorkout(uuid)
        XCTAssertEqual(deleted, 1)
        let suite = "DeletedWorkout.receiver." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let target = root.appendingPathComponent("receiver.store")
        for attempt in 0..<2 {
            let container = try diskStore(at: target)
            let context = container.mainContext
            let before = try await readWorkout(fixture)
            XCTAssertTrue(before.isEmpty)
            let beforeCount = try context.fetchCount(FetchDescriptor<ExerciseRecord>())
            XCTAssertEqual(beforeCount, attempt)
            if attempt == 1 {
                let coldRecords = try context.fetch(FetchDescriptor<ExerciseRecord>())
                let model = ExerciseViewModel(personalRecordStore: PersonalRecordStore(defaults: defaults))
                model.manualRecords = coldRecords
                model.healthKitWorkouts = before
                try verifyLists(model, summaries: before, records: coldRecords, fixture: fixture)
                let locations = try context.fetch(FetchDescriptor<WorkoutLocationRecord>())
                let pin = CardioAtlasSection.savedLocation(in: locations, localID: fixture.recordID, healthID: uuid.uuidString)
                XCTAssertEqual(pin?.payload?.place, fixture.place)
            }
            let result = try await restore(fixture, context: context, defaults: defaults)
            if attempt == 1 { XCTAssertEqual(result.insertedRowCount, 0) }
            let after = try await readWorkout(fixture)
            XCTAssertTrue(after.isEmpty)
            let records = try context.fetch(FetchDescriptor<ExerciseRecord>())
            let model = ExerciseViewModel(personalRecordStore: PersonalRecordStore(defaults: defaults))
            model.manualRecords = records
            model.healthKitWorkouts = after
            try verifyLists(model, summaries: after, records: records, fixture: fixture)
            let locations = try context.fetch(FetchDescriptor<WorkoutLocationRecord>())
            XCTAssertEqual(locations.count, 1)
            let pin = CardioAtlasSection.savedLocation(in: locations, localID: fixture.recordID, healthID: uuid.uuidString)
            XCTAssertEqual(pin?.payload?.place, fixture.place)
        }
    }

    private func requireAuthorizedSimulator() throws {
        let env = ProcessInfo.processInfo.environment
        guard let id = env["DUNE_HEALTHKIT_QA_SIMULATOR_UDID"], !id.isEmpty,
              env["SIMULATOR_UDID"] == id, UIDevice.current.userInterfaceIdiom == .phone,
              SimulatorAdvancedMockDataProvider.current() == nil else {
            throw XCTSkip("Select the owned iPhone simulator with real HealthKit.")
        }
        guard HKHealthStore.isHealthDataAvailable(),
              HKHealthStore().authorizationStatus(for: .workoutType()) == .sharingAuthorized else {
            throw XCTSkip("Grant DUNE workout read and write access on the owned simulator.")
        }
    }

    private func verifyArrival(healthFirst: Bool) async throws {
        try requireAuthorizedSimulator()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try makeSource(in: source, archiveDirectory: root)
        try FileManager.default.removeItem(at: source)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))

        let target = root.appendingPathComponent("new-device.store")
        let suite = "Arrival.receiver." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        do {
            let container = try diskStore(at: target)
            let context = container.mainContext
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseRecord>()), 0)
            let absent = try await readWorkout(fixture)
            XCTAssertTrue(absent.isEmpty)
            let model = ExerciseViewModel(personalRecordStore: PersonalRecordStore(defaults: defaults))
            if healthFirst {
                try await deliverWorkout(fixture.workout)
                let summaries = try await readWorkout(fixture)
                model.healthKitWorkouts = summaries
                let row = try XCTUnwrap(model.allExercises.first)
                XCTAssertEqual(row.source, .healthKit)
                XCTAssertEqual(row.completedSets.map(\.id), fixture.sets)
                XCTAssertEqual(row.personalRecordTypes, [.longestDuration])
                let store = PersonalRecordStore(defaults: defaults)
                XCTAssertEqual(store.rewardHistory(), fixture.rewards)
                ActivityViewModel(personalRecordStore: store).refreshCardioPersonalRecords(with: summaries)
                XCTAssertEqual(store.rewardHistory(), fixture.rewards)
            }
            _ = try await restore(fixture, context: context, defaults: defaults)
            model.manualRecords = try context.fetch(FetchDescriptor<ExerciseRecord>())
            if !healthFirst {
                XCTAssertEqual(model.allExercises.map(\.id), [fixture.recordID.uuidString])
                let beforeDelivery = try await readWorkout(fixture)
                XCTAssertTrue(beforeDelivery.isEmpty)
                try await deliverWorkout(fixture.workout)
            }
            let arrived = try await readWorkout(fixture)
            model.healthKitWorkouts = arrived
            let rewards = PersonalRecordStore(defaults: defaults)
            ActivityViewModel(personalRecordStore: rewards).refreshCardioPersonalRecords(with: arrived)
            XCTAssertEqual(rewards.rewardHistory(), fixture.rewards)
            XCTAssertEqual(rewards.records(for: .stairClimbing)[.longestDuration]?.isIndoor, true)
            try verifyLists(model, summaries: arrived, records: model.manualRecords, fixture: fixture)
        }

        let reopened = try diskStore(at: target)
        let context = reopened.mainContext
        let records = try context.fetch(FetchDescriptor<ExerciseRecord>())
        let summaries = try await readWorkout(fixture)
        XCTAssertEqual(summaries.map(\.id), [fixture.workout.uuid.uuidString])
        XCTAssertEqual(summaries.first?.strengthArchive?.recordID, fixture.recordID)
        let account = PersonalRecordStore(defaults: defaults)
        let model = ExerciseViewModel(personalRecordStore: account)
        model.manualRecords = records
        model.healthKitWorkouts = summaries
        try verifyLists(model, summaries: summaries, records: records, fixture: fixture)
        let sets = try context.fetch(FetchDescriptor<WorkoutSet>())
        XCTAssertEqual(sets.count, fixture.sets.count)
        XCTAssertTrue(sets.allSatisfy { $0.exerciseRecord?.id == fixture.recordID })
        let places = try context.fetch(FetchDescriptor<WorkoutLocationRecord>())
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.localRecordID, fixture.recordID)
        let native = try XCTUnwrap(summaries.first)
        XCTAssertTrue(native.activityType.isAtlasSupported)
        let linked = LinkedWorkoutDetail.record(in: records, archiveRecordID: native.strengthArchive?.recordID)
        XCTAssertEqual(linked?.id, fixture.recordID)
        XCTAssertEqual(LinkedWorkoutDetail.sets(record: linked, archive: native.strengthArchive)?.map(\.id), fixture.sets)
        let pin = CardioAtlasSection.savedLocation(in: places, localID: linked?.id, healthID: native.id)
        XCTAssertEqual(pin?.payload?.isIndoor, true)
        XCTAssertEqual(pin?.payload?.place, fixture.place)
        let photos = try context.fetch(FetchDescriptor<PostureAssessmentRecord>())
        XCTAssertEqual(photos.map(\.id), [fixture.portraitID])
        XCTAssertEqual(Data(SHA256.hash(data: try XCTUnwrap(photos.first?.frontImageData))), fixture.photoHash)
        XCTAssertEqual(account.records(for: .stairClimbing)[.longestDuration]?.workoutID,
                       fixture.workout.uuid.uuidString)
        ActivityViewModel(personalRecordStore: account).refreshCardioPersonalRecords(with: summaries)
        XCTAssertEqual(account.records(for: .stairClimbing)[.longestDuration]?.isIndoor, true)
        XCTAssertEqual(account.rewardHistory(), fixture.rewards)
        let repeated = try await restore(fixture, context: context, defaults: defaults)
        XCTAssertEqual(repeated.insertedRowCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExerciseRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSet>()), 2)
        XCTAssertEqual(account.rewardHistory(), fixture.rewards)
    }

    private func verifyLists(_ model: ExerciseViewModel, summaries: [WorkoutSummary], records: [ExerciseRecord],
                             fixture: Fixture) throws {
        let (recent, destinations) = ExerciseListSection(workouts: summaries, exerciseRecords: records,
                                                        rewardEvents: fixture.rewards).buildItemsAndIndex()
        for rows in [model.allExercises, recent] {
            XCTAssertEqual(rows.map(\.id), [fixture.recordID.uuidString])
            let row = try XCTUnwrap(rows.first)
            XCTAssertEqual(row.source, .manual)
            XCTAssertEqual(row.linkedWorkoutID, fixture.workout.uuid.uuidString)
            XCTAssertEqual(row.completedSets.map(\.id), fixture.sets)
            XCTAssertEqual(row.completedSets.compactMap(\.reps), [8, 6])
            XCTAssertEqual(row.completedSets.compactMap(\.weight), [15, 20])
        }
        XCTAssertEqual(destinations[fixture.recordID]?.memo, "Synthetic detail note")
    }

    private func diskStore(at url: URL) throws -> ModelContainer {
        let schema = AppSchema.currentSchema
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        XCTAssertFalse(config.isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func readWorkout(_ fixture: Fixture) async throws -> [WorkoutSummary] {
        let workout = fixture.workout
        return try await WorkoutQueryService(manager: .shared)
            .fetchWorkouts(start: workout.startDate.addingTimeInterval(-1), end: workout.endDate.addingTimeInterval(1))
            .filter { $0.id == workout.uuid.uuidString || $0.strengthArchive?.recordID == fixture.recordID }
    }

    private func deliverWorkout(_ workout: HKWorkout) async throws {
        try await HKHealthStore().save(workout)
        let uuid = workout.uuid
        addTeardownBlock {
            let removed = try await Self.removeOwnedWorkout(uuid)
            XCTAssertEqual(removed, 1)
        }
    }

    private nonisolated static func removeOwnedWorkout(_ uuid: UUID) async throws -> Int {
        try await HKHealthStore().deleteObjects(of: .workoutType(), predicate: ownedWorkoutPredicate(uuid))
    }

    private nonisolated static func ownedWorkoutPredicate(_ uuid: UUID) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObject(with: uuid), HKQuery.predicateForObjects(from: HKSource.default())
        ])
    }

    private func restore(_ fixture: Fixture, context: ModelContext,
                         defaults: UserDefaults) async throws -> AppOwnedBackup.RestoreResult {
        let workflow = BackupFileWorkflow()
        await workflow.selectFile(.success(fixture.url))
        workflow.inputKey = fixture.key
        await workflow.restore(context: context, defaults: defaults)
        if workflow.canCombine {
            workflow.confirmedOwnership = true
            workflow.inputKey = fixture.key
            await workflow.restore(context: context, defaults: defaults)
        }
        let result = try XCTUnwrap(workflow.restoredRecords)
        XCTAssertEqual(result.workoutCount, 1)
        XCTAssertEqual(result.setCount, 2)
        return result
    }

    private func makeSource(in directory: URL, archiveDirectory: URL) throws -> Fixture {
        let source = try diskStore(at: directory.appendingPathComponent("old-device.store"))
        let suite = "Arrival.source." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) - 180)
        let title = WorkoutActivityType.stairClimbing.rawValue
        let record = ExerciseRecord(date: start, exerciseType: title, duration: 120, memo: "Synthetic detail note")
        let first = WorkoutSet(setNumber: 1, weight: 15, reps: 8, isCompleted: true)
        let second = WorkoutSet(setNumber: 2, weight: 20, reps: 6, isCompleted: true)
        record.sets = [first, second]
        let archive = try XCTUnwrap(WorkoutStrengthArchive(record: record))
        var metadata = HealthKitWorkoutTitle.metadata(exerciseName: title)
        metadata[WorkoutStrengthArchive.metadataKey] = try XCTUnwrap(archive.encodedMetadata())
        metadata[HKMetadataKeyIndoorWorkout] = true
        let workout = HKWorkout(activityType: .stairClimbing, start: start,
                                end: start.addingTimeInterval(120), duration: 120,
                                totalEnergyBurned: nil, totalDistance: nil, metadata: metadata)
        let hkID = workout.uuid.uuidString
        record.healthKitWorkoutID = hkID
        let place = try XCTUnwrap(WorkoutPlace(latitude: 0.125, longitude: 0.25, name: "Synthetic gym", source: .manual))
        let location = WorkoutLocationRecord(localRecordID: record.id, payload: WorkoutLocationPayload(isIndoor: true, place: place))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { renderer in
            UIColor.blue.setFill()
            renderer.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let portrait = PostureAssessmentRecord(frontImageData: image)
        let context = source.mainContext
        context.insert(record)
        context.insert(location)
        context.insert(portrait)
        try context.save()
        let summary = WorkoutSummary(id: hkID, type: title, activityType: .stairClimbing,
                                     duration: 120, calories: nil, distance: nil, date: start, isFromThisApp: true)
        let store = PersonalRecordStore(defaults: defaults)
        let types = store.updateIfNewRecords(summary)
        _ = store.evaluateReward(for: summary, newPRTypes: types)
        let events = store.rewardHistory()
        XCTAssertFalse(events.isEmpty)
        let key = EncryptedRecoveryArchive.makeRecoveryKey()
        let url = archiveDirectory.appendingPathComponent("synthetic.dunebackup")
        let plaintext = try AppOwnedBackup.encode(from: context, defaults: defaults)
        try EncryptedRecoveryArchive.seal(plaintext, recoveryKey: key).write(to: url, options: .atomic)
        return Fixture(workout: workout, recordID: record.id, sets: [first.id, second.id], place: place,
                       portraitID: portrait.id, photoHash: Data(SHA256.hash(data: image)),
                       rewards: events, key: key, url: url)
    }
}
#endif
