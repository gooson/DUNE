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

    @Test("Selected workout read failure is unavailable rather than absent")
    func selectedWorkoutReadFailure() async throws {
        let clock = now
        let service = HealthQueryService(container: try store(),
            workoutService: QueryWorkoutStub(onFetch: { throw CocoaError(.fileReadUnknown) }), nowProvider: { clock })
        let response = try await service.execute(HealthQueryRequest(kind: .latestWorkout, workoutID: "missing"))
        #expect(response.status == .unavailable)
        #expect(!response.isComplete)
        #expect(response.records.isEmpty)
    }

    @Test("Batch identifiers filter before the display cap and load history once")
    func batchWorkoutLookup() async throws {
        let probe = QueryAccessProbe()
        let clock = now
        let records = (0..<60).map { index in
            WorkoutSummary(id: "remote-\(index)", type: "Running", activityType: .running,
                           duration: 600, calories: nil, distance: nil, date: now.addingTimeInterval(Double(-60 - index)))
        }
        let service = HealthQueryService(container: try store(),
            workoutService: QueryWorkoutStub(records: records, onFetch: { await probe.didFetch() }), nowProvider: { clock })
        let response = try await service.execute(HealthQueryRequest(kind: .workoutSummary, limit: 2,
            workoutIDs: ["healthkit:remote-59", "remote-58"]))
        #expect(Set(response.records.compactMap(\.healthKitWorkoutID)) == Set(["remote-58", "remote-59"]))
        #expect(probe.fetchCount == 1)
        #expect(response.metrics.first { $0.id == "records" }?.value == 2)
    }

    @Test("Oversized batches and identifiers are rejected without silently dropping records")
    func batchRequestBounds() async throws {
        let identifiers = (0..<50).map { "id-\($0)" }
        let request = HealthQueryRequest(kind: .workoutSummary, workoutIDs: identifiers)
        #expect(request.workoutIDs == identifiers)
        let probe = QueryAccessProbe()
        let clock = now
        let service = HealthQueryService(container: try store(),
            workoutService: QueryWorkoutStub(onFetch: { await probe.didFetch() }), nowProvider: { clock })
        let oversized = try await service.execute(request)
        #expect(oversized.status == .invalidRequest)
        let invalid = try await service.execute(HealthQueryRequest(kind: .workoutSummary,
            workoutIDs: [String(repeating: "a", count: 201)]))
        #expect(invalid.status == .invalidRequest)
        #expect(probe.fetchCount == 0)
    }

    @Test("Set-only days do not fabricate zero duration points")
    func missingDurationSeries() {
        let service = HealthQueryService()
        let setOnly = HealthQueryWorkoutSnapshot(id: "set-only", name: "Squat", date: now,
            completedSets: [HealthQuerySetSnapshot(id: "set", number: 1, weightKilograms: 50, reps: 5)])
        let interval = DateInterval(start: now.addingTimeInterval(-86_400), end: now.addingTimeInterval(1))
        #expect(service.dailySeries([setOnly], interval: interval).points.isEmpty)
        let timed = HealthQueryWorkoutSnapshot(id: "timed", name: "Run", date: now, durationSeconds: 90)
        #expect(service.dailySeries([setOnly, timed], interval: interval).points.map(\.value) == [90])
    }

    @Test("Only actual HealthKit enrichment adds supplemental provenance")
    func enrichmentProvenance() throws {
        let clock = now
        let service = HealthQueryService(nowProvider: { clock })
        let local = HealthQueryWorkoutSnapshot(id: "local", healthKitWorkoutID: "linked", name: "Run", date: now,
                                               durationSeconds: 60, distanceMeters: 200)
        let remoteDate = now.addingTimeInterval(-1)
        let remote = HealthQueryWorkoutSnapshot(id: "remote", healthKitWorkoutID: "linked", name: "Run", date: remoteDate,
            durationSeconds: 70, distanceMeters: 210, averageHeartRate: 130, source: .healthKit)
        let merged = HealthQueryService.mergeWorkouts(local: [local], healthKit: [remote], tombstones: [], fetchedAt: now)
        let sources = service.sources(for: merged)
        #expect(sources.map(\.kind) == [.app, .healthKit])
        #expect(sources.last?.measuredAt == remoteDate)
        #expect(sources.last?.fetchedAt == now)
        var complete = local
        complete.averageHeartRate = 140
        let unchanged = HealthQueryService.mergeWorkouts(local: [complete], healthKit: [remote], tombstones: [], fetchedAt: now)
        #expect(unchanged.first?.supplementalHealthKitSource == nil)
        #expect(service.sources(for: unchanged).count == 1)
    }

    @Test("Fallback dedup crosses bucket boundaries but preserves exact boundary and third-party workouts")
    func bucketedDuplicateMatching() {
        let base = Date(timeIntervalSinceReferenceDate: 120_000)
        let local = HealthQueryWorkoutSnapshot(id: "local", name: "Run", activityType: .running,
                                               date: base.addingTimeInterval(-1), durationSeconds: 60)
        func remote(_ id: String, offset: Double, own: Bool, activity: WorkoutActivityType = .running) -> HealthQueryWorkoutSnapshot {
            HealthQueryWorkoutSnapshot(id: id, healthKitWorkoutID: id, name: "Workout", activityType: activity,
                date: base.addingTimeInterval(offset), durationSeconds: 60, source: .healthKit, isFromThisApp: own)
        }
        let records = [remote("near", offset: 1, own: true), remote("boundary", offset: 119, own: true),
                       remote("third-party", offset: 1, own: false), remote("cycling", offset: 1, own: true, activity: .cycling)]
        let merged = HealthQueryService.mergeWorkouts(local: [local], healthKit: records, tombstones: [])
        #expect(Set(merged.map(\.id)) == Set(["local", "boundary", "third-party", "cycling"]))
        let strength = HealthQueryWorkoutSnapshot(id: "strength", name: "Squat", date: base,
            completedSets: [HealthQuerySetSnapshot(id: "set", number: 1, reps: 3)])
        let strengthRemote = remote("strength-remote", offset: 1, own: true, activity: .traditionalStrengthTraining)
        #expect(HealthQueryService.mergeWorkouts(local: [strength], healthKit: [strengthRemote], tombstones: []).count == 1)
    }

    @Test("Calendar comparisons retain full day boundaries across DST and partial current days")
    func calendarAlignedComparison() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12)))
        let service = HealthQueryService(calendar: calendar)
        for (period, days) in [(HealthQueryPeriod.last7Days, 7), (.last30Days, 30)] {
            let current = period.interval(endingAt: end, calendar: calendar)
            let previous = service.previousComparisonInterval(for: current)
            #expect(previous.end == current.start)
            #expect(previous.start == calendar.startOfDay(for: previous.start))
            #expect(calendar.dateComponents([.day], from: previous.start, to: previous.end).day == days)
            #expect(previous.duration != current.duration)
        }
        let rolling = DateInterval(start: end.addingTimeInterval(-3_600), end: end)
        let previous = service.previousComparisonInterval(for: rolling)
        #expect(previous.duration == rolling.duration)
        #expect(previous.end == rolling.start)
    }

    @Test("Explicit comparison intervals are honored and each history read requests the sentinel cap")
    func explicitComparisonAndQueryCap() async throws {
        let probe = QueryAccessProbe()
        let clock = now
        let current = DateInterval(start: now.addingTimeInterval(-3_600), end: now)
        let previous = DateInterval(start: now.addingTimeInterval(-30_000), end: now.addingTimeInterval(-20_000))
        let service = HealthQueryService(container: try store(),
            workoutService: BoundedQueryWorkoutStub(onFetch: { start, end, limit in
                await probe.didFetchRange(start: start, end: end, limit: limit)
            }), sleepService: EmptyQuerySleepStub(), nowProvider: { clock })
        let response = try await service.execute(HealthQueryRequest(kind: .metricComparison,
            interval: current, comparisonInterval: previous))
        #expect(response.status == .noData)
        #expect(probe.intervals == [current, previous])
        #expect(probe.limits == [2_001, 2_001])
        #expect(!response.limitations.isEmpty)
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
    var intervals: [DateInterval] = []
    var limits: [Int] = []
    func didFetchRange(start: Date, end: Date, limit: Int) {
        intervals.append(DateInterval(start: start, end: end))
        limits.append(limit)
    }
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

private struct BoundedQueryWorkoutStub: WorkoutQuerying {
    let onFetch: @Sendable (Date, Date, Int) async -> Void
    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { throw CocoaError(.fileReadUnknown) }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] { throw CocoaError(.fileReadUnknown) }
    func fetchWorkouts(start: Date, end: Date, limit: Int) async throws -> [WorkoutSummary] {
        await onFetch(start, end, limit)
        return []
    }
}

private struct EmptyQuerySleepStub: SleepQuerying {
    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { [] }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] { [] }
}
