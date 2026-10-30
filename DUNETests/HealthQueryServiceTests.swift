import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("Health query service integrity")
@MainActor
struct HealthQueryServiceTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func store() throws -> ModelContainer {
        try ModelContainer(for: ExerciseRecord.self, WorkoutSet.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test("A locked device returns no health data and does not start HealthKit queries")
    func lockedBeforeRead() async throws {
        let probe = QueryAccessProbe()
        probe.unlocked = false
        let clock = now
        let service = HealthQueryService(container: try store(),
                                         workoutService: QueryWorkoutStub(onFetch: { await probe.didFetch() }),
                                         nowProvider: { clock }, protectedDataProvider: { probe.unlocked })
        let response = try await service.execute(HealthQueryRequest(kind: .latestWorkout))
        #expect(response.status == .locked)
        #expect(response.metrics.isEmpty && response.records.isEmpty && response.sources.isEmpty)
        #expect(probe.fetchCount == 0)
    }

    @Test("Locking while HealthKit is in flight discards the returned records")
    func lockedAfterRead() async throws {
        let probe = QueryAccessProbe()
        let clock = now
        let remote = WorkoutSummary(id: "private", type: "Running", activityType: .running,
                                    duration: 600, calories: 100, distance: 1_000, date: now.addingTimeInterval(-60))
        let service = HealthQueryService(container: try store(),
                                         workoutService: QueryWorkoutStub(records: [remote], onFetch: {
                                             await Task.yield()
                                             await probe.didFetch(lock: true)
                                         }), nowProvider: { clock }, protectedDataProvider: { probe.unlocked })
        let response = try await service.execute(HealthQueryRequest(kind: .latestWorkout))
        #expect(probe.fetchCount == 1)
        #expect(response.status == .locked)
        #expect(response.metrics.isEmpty && response.records.isEmpty && response.sources.isEmpty)
    }

    @Test("Invalid future, oversized and limit requests stop before querying")
    func invalidRequests() async throws {
        let probe = QueryAccessProbe()
        let clock = now
        let service = HealthQueryService(container: try store(),
                                         workoutService: QueryWorkoutStub(onFetch: { await probe.didFetch() }),
                                         nowProvider: { clock })
        let requests = [
            HealthQueryRequest(kind: .latestWorkout, interval: DateInterval(start: now, end: now.addingTimeInterval(60))),
            HealthQueryRequest(kind: .latestWorkout, interval: DateInterval(start: now.addingTimeInterval(-368 * 86_400), end: now)),
            HealthQueryRequest(kind: .latestWorkout, limit: 0),
            HealthQueryRequest(kind: .latestWorkout, limit: 101)
        ]
        for request in requests {
            let response = try await service.execute(request)
            #expect(response.status == .invalidRequest)
            #expect(response.records.isEmpty)
        }
        #expect(probe.fetchCount == 0)
    }

    @Test("Actual completed non-warmup sets determine volume, never planned repetitions")
    func completedSetsProjection() throws {
        let record = ExerciseRecord(date: now, exerciseType: "Squat", duration: 600)
        record.sets = [
            WorkoutSet(setNumber: 1, setType: .warmup, weight: 20, reps: 10, isCompleted: true),
            WorkoutSet(setNumber: 2, weight: 100, reps: 4, isCompleted: true, plannedReps: 10),
            WorkoutSet(setNumber: 3, weight: 120, reps: 5, isCompleted: false),
            WorkoutSet(setNumber: 4, weight: 50, reps: nil, isCompleted: true, plannedReps: 12)
        ]
        let projected = try #require(HealthQueryService.projectWorkout(record))
        #expect(projected.completedSets.count == 2)
        #expect(projected.completedSets.first?.reps == 4)
        #expect(projected.completedSets.last?.reps == nil)
        #expect(projected.volumeKilogramRepetitions == 400)
    }

    @Test("Linked HealthKit workouts enrich once and tombstones suppress both sources")
    func linkedMergeAndTombstones() {
        let local = HealthQueryWorkoutSnapshot(id: "app:local", healthKitWorkoutID: "linked", name: "Run", date: now,
                                               durationSeconds: 600, source: .app)
        let linked = HealthQueryWorkoutSnapshot(id: "hk:linked", healthKitWorkoutID: "linked", name: "Run", date: now,
                                                durationSeconds: 610, distanceMeters: 2_000, averageHeartRate: 140, source: .healthKit)
        let unlinkedWatch = HealthQueryWorkoutSnapshot(id: "hk:watch", healthKitWorkoutID: "watch", name: "Run", date: now,
                                                       durationSeconds: 500, source: .healthKit, isFromThisApp: true)
        let merged = HealthQueryService.mergeWorkouts(local: [local], healthKit: [linked, unlinkedWatch], tombstones: [])
        #expect(merged.count == 2)
        #expect(merged.first { $0.id == local.id }?.durationSeconds == 600)
        #expect(merged.first { $0.id == local.id }?.distanceMeters == 2_000)
        #expect(merged.first { $0.id == local.id }?.averageHeartRate == 140)
        let deleted = HealthQueryService.mergeWorkouts(local: [local], healthKit: [linked, unlinkedWatch], tombstones: ["linked"])
        #expect(deleted.map(\.id) == [unlinkedWatch.id])
    }

    @Test("Comparison chooses the nearest earlier identical exercise rather than the nearest workout")
    func nearestSameExercise() async throws {
        let container = try store()
        let context = ModelContext(container)
        let latest = ExerciseRecord(date: now.addingTimeInterval(-60), exerciseType: "Squat", duration: 600, exerciseDefinitionID: "squat")
        let different = ExerciseRecord(date: now.addingTimeInterval(-120), exerciseType: "Squat", duration: 900, exerciseDefinitionID: "split-squat")
        let nearest = ExerciseRecord(date: now.addingTimeInterval(-180), exerciseType: "Squat", duration: 500, exerciseDefinitionID: "squat")
        let oldest = ExerciseRecord(date: now.addingTimeInterval(-240), exerciseType: "Squat", duration: 400, exerciseDefinitionID: "squat")
        for record in [latest, different, nearest, oldest] { context.insert(record) }
        try context.save()
        let clock = now
        let service = HealthQueryService(container: container, workoutService: QueryWorkoutStub(), nowProvider: { clock })
        let response = try await service.execute(HealthQueryRequest(kind: .workoutComparison))
        #expect(response.records.map(\.localRecordID) == [latest.id, nearest.id])
        #expect(response.metrics.first { $0.id == "duration" }?.comparisonValue == 500)
        #expect(response.metrics.first { $0.id == "duration" }?.comparisonDate == nearest.date)
    }

    @Test("Display limits never truncate whole-period summary statistics")
    func allPeriodAggregation() async throws {
        let container = try store()
        let context = ModelContext(container)
        for offset in 1...3 {
            context.insert(ExerciseRecord(date: now.addingTimeInterval(Double(-offset * 60)), exerciseType: "Running", duration: 600))
        }
        try context.save()
        let clock = now
        let service = HealthQueryService(container: container, workoutService: QueryWorkoutStub(), nowProvider: { clock })
        let response = try await service.execute(HealthQueryRequest(kind: .workoutSummary, limit: 1))
        #expect(response.records.count == 1)
        #expect(response.metrics.first { $0.id == "records" }?.value == 3)
        #expect(response.metrics.first { $0.id == "duration" }?.value == 1_800)
    }

    @Test("Cancellation thrown by a query propagates without becoming an unavailable result")
    func cancellationPropagation() async throws {
        let clock = now
        let service = HealthQueryService(container: try store(),
                                         workoutService: QueryWorkoutStub(onFetch: { throw CancellationError() }), nowProvider: { clock })
        do {
            _ = try await service.execute(HealthQueryRequest(kind: .latestWorkout))
            Issue.record("Expected CancellationError")
        } catch is CancellationError {
            // A cancelled operation must not return health data or a misleading no-data result.
        }
    }
}

@MainActor
private final class QueryAccessProbe {
    var unlocked = true
    var fetchCount = 0
    func didFetch(lock: Bool = false) {
        fetchCount += 1
        if lock { unlocked = false }
    }
}

private struct QueryWorkoutStub: WorkoutQuerying {
    var records: [WorkoutSummary] = []
    var onFetch: @Sendable () async throws -> Void = {}
    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        try await onFetch()
        return records
    }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        try await onFetch()
        return records
    }
}
