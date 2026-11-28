import Foundation
import Testing
@testable import DUNE

@Suite("Cardio Atlas source identity")
@MainActor
struct CardioAtlasHistoryTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("A different known local link never consumes a simultaneous Watch history entry")
    func differentKnownIdentity() {
        let record = ExerciseRecord(date: date, exerciseType: "running", duration: 600, distance: 2)
        record.healthKitWorkoutID = "HK-outside-history-page"
        let watch = workout(id: "HK-simultaneous-watch", fromApp: true)
        let result = CardioAtlasHistory.sessions(records: [record], workouts: [watch], current: session(id: record.id.uuidString))
        #expect(result.count == 2)
        #expect(result.contains { $0.id == watch.id })
    }

    @Test("Local kilometers convert to meters and linked HealthKit samples count once")
    func linkedSources() throws {
        let record = ExerciseRecord(date: date, exerciseType: "running", duration: 600, distance: 2)
        record.healthKitWorkoutID = "atlas-history-linked"
        let current = session(id: record.id.uuidString)
        let imported = workout(id: "atlas-history-linked", fromApp: true)
        let result = CardioAtlasHistory.sessions(records: [record], workouts: [imported], current: current)
        #expect(result.count == 1)
        #expect(result.first?.distanceMeters == 2_000)
    }

    @Test("An imported detail replaces its local alias and keeps unrelated Watch workouts")
    func importedDetailAlias() {
        let record = ExerciseRecord(date: date, exerciseType: "running", duration: 600, distance: 2)
        record.healthKitWorkoutID = "atlas-history-current"
        let current = session(id: "atlas-history-current")
        let watch = WorkoutSummary(
            id: "atlas-history-watch", type: "Running", activityType: .running,
            duration: 1_200, calories: nil, distance: 3_000,
            date: date.addingTimeInterval(-3_600), isFromThisApp: true
        )
        let result = CardioAtlasHistory.sessions(records: [record], workouts: [watch], current: current)
        #expect(Set(result.map(\.id)) == [current.id, watch.id])
    }

    @Test("Floors remain duration progress and broad cardio categories are supported")
    func nonDistanceAndCategories() {
        let record = ExerciseRecord(date: date, exerciseType: "stairClimbing", duration: 900)
        record.floorsAscended = 30
        let current = CardioAtlasSession(
            id: "another-stair-session", activityType: .stairClimbing,
            date: date.addingTimeInterval(1_000), duration: 600, distanceMeters: nil
        )
        let result = CardioAtlasHistory.sessions(records: [record], workouts: [], current: current)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.distanceMeters == nil })
        #expect(WorkoutActivityType.swimming.isAtlasSupported)
        #expect(WorkoutActivityType.elliptical.isAtlasSupported)
        #expect(WorkoutActivityType.cardioDance.isAtlasSupported)
        #expect(WorkoutActivityType.swimBikeRun.isAtlasSupported)
        #expect(!WorkoutActivityType.traditionalStrengthTraining.isAtlasSupported)
    }

    @Test("An open session detail adopts restored set identities without borrowing sibling exercises")
    func restoreLinkedDetailSets() throws {
        let record = ExerciseRecord(date: date, exerciseType: "strength", duration: 120)
        let sibling = ExerciseRecord(date: date, exerciseType: "strength", duration: 120)
        for row in [record, sibling] { row.healthKitWorkoutID = "shared-session" }
        let set = WorkoutSet(setNumber: 1, weight: 20, reps: 5, isCompleted: true)
        record.sets = [set]
        let archive = try #require(WorkoutStrengthArchive(record: record))
        set.reps = 7
        let before = LinkedWorkoutDetail.sets(record: nil, archive: archive)
        #expect(before?.first?.reps == 5)
        let after = LinkedWorkoutDetail.record(in: [sibling, record], archiveRecordID: archive.recordID)
        let sets = LinkedWorkoutDetail.sets(record: after, archive: archive)
        #expect(sets?.map(\.id) == [set.id])
        #expect(sets?.first?.reps == 7)
        #expect(LinkedWorkoutDetail.record(in: [sibling, record], archiveRecordID: nil) == nil)
        #expect(LinkedWorkoutDetail.record(in: [sibling], archiveRecordID: record.id) == nil)
        #expect(LinkedWorkoutDetail.record(in: [record], archiveRecordID: nil)?.id == record.id)
    }

    @Test("A restored local-only pin takes priority over the HealthKit session place")
    func restoredLocalOnlyPin() throws {
        let record = ExerciseRecord(date: date, exerciseType: "stairClimbing", duration: 600)
        record.healthKitWorkoutID = "indoor-session"
        let place = try #require(WorkoutPlace(latitude: 1, longitude: 2, name: "Test pin", source: .manual))
        let local = WorkoutLocationRecord(localRecordID: record.id, payload: WorkoutLocationPayload(place: place))
        let remote = WorkoutLocationRecord(healthKitWorkoutID: "indoor-session", payload: WorkoutLocationPayload())
        let sibling = WorkoutLocationRecord(localRecordID: UUID(), healthKitWorkoutID: "indoor-session",
                                            payload: WorkoutLocationPayload())
        let linked = LinkedWorkoutDetail.record(in: [record], archiveRecordID: nil)
        #expect(CardioAtlasSection.savedLocation(in: [remote, sibling, local], localID: linked?.id,
                                                healthID: record.healthKitWorkoutID)?.payload?.place == place)
        #expect(CardioAtlasSection.savedLocation(in: [sibling, local], localID: nil,
                                                healthID: record.healthKitWorkoutID, allowsUnresolvedLocation: false) == nil)
        #expect(CardioAtlasSection.savedLocation(in: [sibling], localID: nil, healthID: record.healthKitWorkoutID)?.id == sibling.id)
    }

    private func session(id: String) -> CardioAtlasSession {
        CardioAtlasSession(id: id, activityType: .running, date: date, duration: 600, distanceMeters: 2_000)
    }

    private func workout(id: String, fromApp: Bool) -> WorkoutSummary {
        WorkoutSummary(id: id, type: "Running", activityType: .running, duration: 600,
                       calories: nil, distance: 2_000, date: date, isFromThisApp: fromApp)
    }
}

#if os(iOS) && targetEnvironment(simulator)
import SwiftData
import SwiftUI
import UIKit
import Vision
import XCTest

@MainActor
final class CardioAtlasLiveRestorePresentationTests: XCTestCase {
    func testOpenStairDetailShowsRestoredLocalPin() async throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("Requires an iPhone simulator") }
        let schema = AppSchema.currentSchema
        func store() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: ModelConfiguration(
                schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
            ))
        }
        let source = try store()
        let destination = try store()
        let suite = "AtlasPresentation." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let workoutID = UUID().uuidString
        let sample = WorkoutSummary(id: workoutID, type: "Stair Climbing", activityType: .stairClimbing,
                                    duration: 300, calories: nil, distance: nil, date: date, isIndoor: true)
        let record = ExerciseRecord(date: date, exerciseType: "stairClimbing", duration: 300)
        record.healthKitWorkoutID = workoutID
        let set = WorkoutSet(setNumber: 1, reps: 73, isCompleted: true)
        let place = try XCTUnwrap(WorkoutPlace(latitude: 0.125, longitude: 0.25, name: "Cobalt Test Gym", source: .manual))
        let pin = WorkoutLocationRecord(localRecordID: record.id, payload: WorkoutLocationPayload(isIndoor: true, place: place))
        source.mainContext.insert(record)
        source.mainContext.insert(set)
        set.exerciseRecord = record
        source.mainContext.insert(pin)
        try source.mainContext.save()
        let key = EncryptedRecoveryArchive.makeRecoveryKey()
        let bytes = try AppOwnedBackup.encode(from: source.mainContext, defaults: defaults)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try EncryptedRecoveryArchive.seal(bytes, recoveryKey: key).write(to: url, options: .atomic)

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; previous?.makeKey() }
        let host = UIHostingController(rootView: NavigationStack { HealthKitWorkoutDetailView(workout: sample) }
            .modelContainer(destination)
            .environment(\.locale, Locale(identifier: "en_US")))
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertFalse(try recognizes(place.name, in: capture(window)))
        let restored = try EncryptedRecoveryArchive.open(Data(contentsOf: url), recoveryKey: key)
        let result = try AppOwnedBackup.restore(restored, into: ModelContext(destination), defaults: defaults)
        XCTAssertEqual(result.archiveRowCount, 3)

        // Wait for live queries in the existing window. The assertion reads only the guest pixels.
        var final: UIImage?
        for attempt in 0..<15 {
            if attempt == 7, let scroll = detailScrollView(in: host.view) {
                let offset = min(scroll.bounds.height / 3, scroll.contentSize.height - scroll.bounds.height)
                scroll.setContentOffset(CGPoint(x: 0, y: max(offset, 0)), animated: false)
            }
            try await Task.sleep(for: .milliseconds(200))
            let image = capture(window)
            if try recognizes(place.name, in: image) {
                final = image
                break
            }
        }
        XCTAssertTrue(window.rootViewController === host)
        let image = final ?? capture(window)
        let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
        attachment.name = "stair-detail-restored-local-pin.png"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertNotNil(final, "The open stair detail must display the restored local-only place name.")
    }

    private func detailScrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height + 100 { return scroll }
        for child in view.subviews {
            if let scroll = detailScrollView(in: child) { return scroll }
        }
        return nil
    }

    private func capture(_ window: UIWindow) -> UIImage {
        window.layoutIfNeeded()
        return UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
    }

    private func recognizes(_ expected: String, in image: UIImage) throws -> Bool {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        let cgImage = try XCTUnwrap(image.cgImage)
        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        return text.localizedCaseInsensitiveContains(expected)
    }
}
#endif
