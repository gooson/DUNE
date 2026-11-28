import Foundation
import Testing
@testable import DUNE

@Suite("Restoring a read-only workout history")
struct NearbyWorkoutRestoreTests {
    private let now = Date.now
    private func entry(id: UUID, title: String = "Stair Climbing", date: Date? = nil) throws -> NearbyWorkoutHistory.Entry {
        let place = try #require(WorkoutPlace(latitude: 1, longitude: 2, name: "Test gym", source: .manual))
        let w = WorkoutSummary(id: id.uuidString, type: title, activityType: .stairClimbing,
                               duration: 2040, calories: 326, distance: nil, date: date ?? now.addingTimeInterval(-3600))
        return .init(workout: w, location: .init(isIndoor: true, place: place))
    }

    @Test func coldStartRetryAndAccountIsolation() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID()
        let e = try entry(id: id)
        let current = NearbyWorkoutHistory(version: 1, fetchedAt: now, entries: [e])
        let bytes = try JSONEncoder().encode(current)
        let first = NearbyWorkoutCache(root: root)
        try await first.accept(bytes, scope: "test-A")
        try await first.accept(bytes, scope: "test-A")
        let restored = NearbyWorkoutCache(root: root)
        let stale = NearbyWorkoutHistory(version: 1, fetchedAt: now.addingTimeInterval(-60), entries: [])
        try await restored.accept(JSONEncoder().encode(stale), scope: "test-A")
        let workouts = try await restored.workouts(start: .distantPast, end: now, scope: "test-A")
        #expect(workouts.map(\.id) == [id.uuidString])
        #expect(workouts.first?.calories == 326)
        #expect(try await restored.location(id: id.uuidString, scope: "test-A") == e.location)
        #expect(try await restored.workouts(start: .distantPast, end: now, scope: "test-B").isEmpty)
        #expect(try await restored.workouts(start: .distantPast, end: now, scope: nil).isEmpty)
        #expect(try await restored.workouts(start: now, end: .distantFuture, scope: "test-A").isEmpty)
    }

    private func packet(
        from source: UUID, at offset: TimeInterval, entries: [NearbyWorkoutHistory.Entry], deleted: Set<UUID> = []
    ) throws -> Data {
        try JSONEncoder().encode(NearbyWorkoutHistory(version: 2, fetchedAt: now.addingTimeInterval(offset),
                                                      entries: entries, deletedIDs: deleted, sourceID: source))
    }

    @Test func multiplePublishersKeepIndependentProgressAndExplicitPlaceRemoval() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let phone = UUID(), pad = UUID(), id = UUID(), second = UUID()
        let first = try entry(id: id)
        let other = try entry(id: second)
        let missing = NearbyWorkoutHistory.Entry(workout: first.workout, location: nil)
        let cache = NearbyWorkoutCache(root: root)

        try await cache.accept(packet(from: phone, at: -15, entries: [first]), scope: "owner")
        try await cache.accept(packet(from: pad, at: -20, entries: [missing, other]), scope: "owner")
        try await cache.accept(packet(from: pad, at: -10, entries: []), scope: "owner")
        #expect(try await cache.workouts(start: .distantPast, end: now, scope: "owner").count == 2)
        #expect(try await cache.location(id: id.uuidString, scope: "owner") == first.location)

        let clear = NearbyWorkoutHistory.Entry(workout: first.workout, location: .init(isIndoor: true),
                                               placeEditedAt: now.addingTimeInterval(-8))
        try await cache.accept(packet(from: pad, at: -7, entries: [clear]), scope: "owner")
        try await cache.accept(packet(from: phone, at: -5, entries: [first]), scope: "owner")
        try await cache.accept(packet(from: pad, at: -9, entries: [first]), scope: "owner")
        #expect(try await cache.location(id: id.uuidString, scope: "owner")?.place == nil)
    }

    @Test func explicitDeletionSurvivesStalePeersAndColdStart() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let phone = UUID(), pad = UUID(), id = UUID()
        let item = try entry(id: id)
        let cache = NearbyWorkoutCache(root: root)
        try await cache.accept(packet(from: phone, at: -9, entries: [item]), scope: "owner")
        try await cache.accept(packet(from: pad, at: -7, entries: [], deleted: [id]), scope: "owner")
        let restored = NearbyWorkoutCache(root: root)
        try await restored.accept(packet(from: phone, at: -5, entries: [item]), scope: "owner")
        try await restored.accept(packet(from: pad, at: -3, entries: []), scope: "owner")
        #expect(try await restored.workouts(start: .distantPast, end: now, scope: "owner").isEmpty)
        #expect(try await restored.location(id: id.uuidString, scope: "owner") == nil)
    }

    @Test func rejectedInputPreservesPreviousArchive() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = UUID(), id = UUID()
        let item = try entry(id: id)
        let cache = NearbyWorkoutCache(root: root)
        try await cache.accept(packet(from: source, at: -1, entries: [item]), scope: "owner")
        await #expect(throws: (any Error).self) { try await cache.accept(Data([0xff]), scope: "owner") }
        let restored = NearbyWorkoutCache(root: root)
        #expect(try await restored.workouts(start: .distantPast, end: now, scope: "owner").map(\.id) == [id.uuidString])
        let path = try #require(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
        try Data([1, 2, 3]).write(to: path)
        let corrupt = NearbyWorkoutCache(root: root)
        await #expect(throws: (any Error).self) {
            try await corrupt.accept(self.packet(from: source, at: 0, entries: [item]), scope: "owner")
        }
        #expect(try Data(contentsOf: path) == Data([1, 2, 3]))
    }

    @Test func savedPlaceIsAuthoritativeAndRouteCanComeFromHealth() throws {
        let location = try #require(entry(id: UUID()).location)
        let point = try #require(WorkoutRoutePoint(latitude: 1, longitude: 2, timestamp: now))
        let health = WorkoutLocationPayload(isIndoor: true, route: [point], place: location.place)
        let cleared = WorkoutLocationPayload(isIndoor: true)
        let displayed = try #require(NearbyWorkoutHistory.displayLocation(saved: cleared, health: health, indoor: nil))
        #expect(displayed.place == nil)
        #expect(displayed.route == health.route)
        #expect(NearbyWorkoutHistory.displayLocation(saved: nil, health: health, indoor: nil) == health)
    }

    @Test func anchoredRestoreHasNoAgeCutoffAndResumesAfterColdStart() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = UUID(), id = UUID()
        let cache = NearbyWorkoutCache(root: root)
        let recent = try await cache.request(source: source, scope: "owner")
        #expect(recent.includesHealthSnapshot)
        let seed = NearbyWorkoutHistory(version: 3, fetchedAt: now, entries: [], sourceID: source, request: recent)
        try await cache.accept(JSONEncoder().encode(seed), scope: "owner")
        let first = try await cache.request(source: source, scope: "owner")
        #expect(first.kind == .changes && first.anchor == nil)
        let old = try entry(id: id, date: now.addingTimeInterval(-5 * 365 * 86_400))
        let cursor = Data([1, 2, 3])
        let page = NearbyWorkoutHistory(version: 3, fetchedAt: now, entries: [old], sourceID: source,
                                        request: first, nextAnchor: cursor, hasMore: true)
        try await cache.accept(JSONEncoder().encode(page), scope: "owner")
        let restored = NearbyWorkoutCache(root: root)
        let next = try await restored.request(source: source, scope: "owner")
        #expect(next.anchor == cursor)
        #expect(try await restored.workouts(start: .distantPast, end: now, scope: "owner").first?.id == id.uuidString)
        let removed = NearbyWorkoutHistory(version: 3, fetchedAt: now, entries: [], deletedIDs: [id], sourceID: source,
                                           request: next, nextAnchor: Data([4]), hasMore: false)
        try await restored.accept(JSONEncoder().encode(removed), scope: "owner")
        try await restored.accept(JSONEncoder().encode(page), scope: "owner")
        #expect(try await restored.request(source: source, scope: "owner").kind == .idle)
        #expect(try await restored.workouts(start: .distantPast, end: now, scope: "owner").isEmpty)
    }

    @Test func olderSavedPlaceEditsPropagateWithoutWorkoutMutation() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = UUID(), id = UUID()
        let cache = NearbyWorkoutCache(root: root)
        let item = try entry(id: id)
        try await cache.accept(packet(from: source, at: -1, entries: [item]), scope: "owner")
        let request = try await cache.request(source: source, scope: "owner")
        let edit = NearbyWorkoutHistory.PlaceEdit(cursor: .init(date: now, id: id), location: .init(isIndoor: true))
        let page = NearbyWorkoutHistory(version: 3, fetchedAt: now, entries: [], sourceID: source, request: request,
                                        nextAnchor: Data([1]), hasMore: true, placeEdits: [edit])
        try await cache.accept(JSONEncoder().encode(page), scope: "owner")
        #expect(try await cache.request(source: source, scope: "owner").placeCursor == edit.cursor)
        #expect(try await cache.location(id: id.uuidString, scope: "owner")?.place == nil)
    }

    @Test func healthSnapshotSurvivesColdStartAndStalePeers() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = NearbyWorkoutCache(root: root)
        func page(_ source: UUID, fetched: Date, steps: Double) throws -> Data {
            let payload = HealthSnapshotMirrorMapper.Payload(
                fetchedAt: fetched, failedSources: [], todayRHR: nil, yesterdayRHR: nil, latestRHR: nil,
                hrv14Day: [], rhr14Day: [], sleep14Day: [], todaySleepMinutes: 0, yesterdaySleepMinutes: 0,
                conditionScore: nil, conditionStatus: nil, conditionContributions: nil, conditionDetail: nil,
                baselineReady: nil, baselineProgress: nil, recentScores: [], todaySteps: steps
            )
            let history = NearbyWorkoutHistory(version: 3, fetchedAt: now, entries: [], sourceID: source,
                request: .init(sourceID: source, kind: .recent), healthSnapshot: payload)
            return try JSONEncoder().encode(history)
        }
        try await cache.accept(page(UUID(), fetched: now, steps: 1234), scope: "owner")
        try await cache.accept(page(UUID(), fetched: now.addingTimeInterval(-60), steps: 20), scope: "owner")
        let restored = NearbyWorkoutCache(root: root)
        #expect(try await restored.healthSnapshot(scope: "owner")?.todaySteps == 1234)
        #expect(try await restored.healthSnapshot(scope: "other") == nil)
    }

    @Test func rejectsMalformedOrAmbiguousTransfers() throws {
        let e = try entry(id: UUID())
        for h in [NearbyWorkoutHistory(version: 2, fetchedAt: now, entries: []),
                  NearbyWorkoutHistory(version: 1, fetchedAt: now, entries: [e, e])] {
            let data = try JSONEncoder().encode(h)
            #expect(throws: CocoaError.self) { try NearbyWorkoutHistory.decode(data) }
        }
        #expect(throws: (any Error).self) { try NearbyWorkoutHistory.decode(Data([123])) }
    }
}
