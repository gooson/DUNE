import Foundation
import Testing
@testable import DUNE

private actor SequencedExerciseWorkoutService: WorkoutQuerying {
    private let dayResults: [[WorkoutSummary]]
    private var nextDayFetchIndex = 0
    private var startedDayFetches: Set<Int> = []
    private var startContinuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private var releaseContinuations: [Int: CheckedContinuation<Void, Never>] = [:]

    init(dayResults: [[WorkoutSummary]]) {
        self.dayResults = dayResults
    }

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        let index = nextDayFetchIndex
        nextDayFetchIndex += 1
        startedDayFetches.insert(index)
        startContinuations[index]?.resume()
        startContinuations[index] = nil

        await withCheckedContinuation { continuation in
            releaseContinuations[index] = continuation
        }

        return dayResults[index]
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        []
    }

    func waitUntilDayFetchStarts(call index: Int) async {
        if startedDayFetches.contains(index) {
            return
        }

        await withCheckedContinuation { continuation in
            startContinuations[index] = continuation
        }
    }

    func resumeDayFetch(call index: Int) {
        releaseContinuations[index]?.resume()
        releaseContinuations[index] = nil
    }
}

@Suite("ExerciseViewModel")
@MainActor
struct ExerciseViewModelTests {
    @Test("allExercises sorted by date descending")
    func sortedByDate() {
        let vm = ExerciseViewModel()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        vm.healthKitWorkouts = [
            WorkoutSummary(id: "1", type: "Running", duration: 1800, calories: 200, distance: nil, date: yesterday),
            WorkoutSummary(id: "2", type: "Cycling", duration: 3600, calories: 400, distance: nil, date: now),
        ]

        #expect(vm.allExercises.count == 2)
        #expect(vm.allExercises[0].type == "Cycling")
        #expect(vm.allExercises[1].type == "Running")
    }

    @Test("HealthKit items have correct source")
    func healthKitSource() {
        let vm = ExerciseViewModel()
        vm.healthKitWorkouts = [
            WorkoutSummary(id: "1", type: "Running", duration: 1800, calories: 200, distance: nil, date: Date()),
        ]

        #expect(vm.allExercises.first?.source == .healthKit)
    }

    // MARK: - Deduplication Tests
    // Edge cases mapped from: docs/plans/2026-02-18-healthkit-dedup.md

    @Test("Filters out HealthKit workout matching SwiftData healthKitWorkoutID")
    func dedupByHealthKitWorkoutID() {
        let vm = ExerciseViewModel()
        let now = Date()
        let hkUUID = "HK-UUID-123"

        let record = ExerciseRecord(
            date: now,
            exerciseType: "Bench Press",
            duration: 1800,
            healthKitWorkoutID: hkUUID
        )

        vm.healthKitWorkouts = [
            WorkoutSummary(id: hkUUID, type: "Strength", duration: 1800, calories: 200, distance: nil, date: now),
        ]
        vm.manualRecords = [record]

        #expect(vm.allExercises.count == 1)
        #expect(vm.allExercises[0].source == .manual)
        #expect(vm.allExercises[0].type == "Bench Press")
    }

    @Test("Keeps external HealthKit workouts without matching SwiftData record")
    func dedupExternalWorkoutsKept() {
        let vm = ExerciseViewModel()
        let now = Date()

        let record = ExerciseRecord(
            date: now,
            exerciseType: "Squat",
            duration: 1200,
            healthKitWorkoutID: "HK-APP-1"
        )

        vm.healthKitWorkouts = [
            WorkoutSummary(id: "HK-APP-1", type: "Strength", duration: 1200, calories: 100, distance: nil, date: now),
            WorkoutSummary(id: "HK-WATCH-1", type: "Running", duration: 1800, calories: 300, distance: 5000, date: now),
        ]
        vm.manualRecords = [record]

        #expect(vm.allExercises.count == 2)
        let sources = vm.allExercises.map(\.source)
        #expect(sources.contains(.manual))
        #expect(sources.contains(.healthKit))
    }

    // Edge case: HealthKit write failure — healthKitWorkoutID never populated
    // Fallback dedup requires isFromThisApp AND matching activityType + date proximity (±2 min)
    @Test("Filters out own app workouts (isFromThisApp) as fallback when healthKitWorkoutID is nil")
    func dedupByIsFromThisApp() {
        let vm = ExerciseViewModel()
        let now = Date()

        let record = ExerciseRecord(
            date: now,
            exerciseType: WorkoutActivityType.traditionalStrengthTraining.rawValue,
            duration: 2400,
            healthKitWorkoutID: nil
        )

        vm.healthKitWorkouts = [
            WorkoutSummary(id: "HK-ORPHAN", type: "Strength", activityType: .traditionalStrengthTraining, duration: 2400, calories: 300, distance: nil, date: now, isFromThisApp: true),
        ]
        vm.manualRecords = [record]

        #expect(vm.allExercises.count == 1)
        #expect(vm.allExercises[0].source == .manual)
    }

    @Test("Filters out strength app workouts when manual set record is time-proximate")
    func dedupStrengthFallbackWithSetData() {
        let vm = ExerciseViewModel()
        let now = Date()

        let record = ExerciseRecord(
            date: now,
            exerciseType: "Bench Press",
            duration: 2400,
            healthKitWorkoutID: nil
        )
        let set = WorkoutSet(setNumber: 1, reps: 10, isCompleted: true)
        set.exerciseRecord = record
        record.sets = [set]

        vm.healthKitWorkouts = [
            WorkoutSummary(
                id: "HK-WATCH-ORPHAN",
                type: "Strength",
                activityType: .traditionalStrengthTraining,
                duration: 2400,
                calories: 280,
                distance: nil,
                date: now,
                isFromThisApp: true
            )
        ]
        vm.manualRecords = [record]

        #expect(vm.allExercises.count == 1)
        #expect(vm.allExercises[0].source == .manual)
    }

    // Edge case: corrupted record with empty string healthKitWorkoutID
    @Test("Ignores empty healthKitWorkoutID during dedup matching")
    func dedupIgnoresEmptyHealthKitWorkoutID() {
        let vm = ExerciseViewModel()
        let now = Date()

        let record = ExerciseRecord(
            date: now,
            exerciseType: "Bench Press",
            duration: 1800,
            healthKitWorkoutID: ""
        )

        vm.healthKitWorkouts = [
            WorkoutSummary(id: "", type: "Strength", duration: 1800, calories: 200, distance: nil, date: now),
        ]
        vm.manualRecords = [record]

        // Empty ID should NOT cause false-positive match; both items should appear
        #expect(vm.allExercises.count == 2)
    }

    @Test("Empty data produces empty list")
    func dedupEmptyData() {
        let vm = ExerciseViewModel()
        vm.healthKitWorkouts = []
        vm.manualRecords = []
        #expect(vm.allExercises.isEmpty)
    }

    @Test("Mixed sources maintain date sort order after dedup")
    func dedupSortOrder() {
        let vm = ExerciseViewModel()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now

        let record = ExerciseRecord(
            date: yesterday,
            exerciseType: "Bench Press",
            duration: 1800,
            healthKitWorkoutID: "HK-1"
        )

        vm.healthKitWorkouts = [
            WorkoutSummary(id: "HK-1", type: "Strength", duration: 1800, calories: 200, distance: nil, date: yesterday),
            WorkoutSummary(id: "HK-WATCH", type: "Running", duration: 1800, calories: 300, distance: 5000, date: now, isFromThisApp: false),
            WorkoutSummary(id: "HK-WATCH-2", type: "Cycling", duration: 3600, calories: 500, distance: nil, date: twoDaysAgo, isFromThisApp: false),
        ]
        vm.manualRecords = [record]

        #expect(vm.allExercises.count == 3)
        #expect(vm.allExercises[0].type == "Running")
        #expect(vm.allExercises[1].type == "Bench Press")
        #expect(vm.allExercises[2].type == "Cycling")
    }

    @Test("Tombstoned HealthKit workouts are excluded from allExercises")
    func tombstonedWorkoutsExcluded() {
        // Use a unique ID to avoid polluting other tests (no public remove API).
        let tombstonedID = "HK-TOMBSTONED-\(UUID().uuidString)"

        // Record tombstone on the shared singleton (same instance used by ExerciseViewModel)
        DeletedWorkoutTombstoneStore.shared.recordDeletion(healthKitWorkoutID: tombstonedID)

        let vm = ExerciseViewModel()
        let now = Date()

        vm.healthKitWorkouts = [
            WorkoutSummary(id: tombstonedID, type: "Running", duration: 1800, calories: 200, distance: 5000, date: now),
            WorkoutSummary(id: "HK-ALIVE-1", type: "Cycling", duration: 3600, calories: 400, distance: nil, date: now),
        ]

        #expect(vm.allExercises.count == 1)
        #expect(vm.allExercises[0].type == "Cycling")
    }

    @Test("Latest workout load wins over older response")
    func latestWorkoutLoadWinsOverOlderResponse() async {
        let now = Date()
        let oldWorkout = WorkoutSummary(
            id: "old",
            type: "Running",
            duration: 1800,
            calories: 200,
            distance: nil,
            date: now.addingTimeInterval(-3600)
        )
        let newWorkout = WorkoutSummary(
            id: "new",
            type: "Cycling",
            duration: 2400,
            calories: 320,
            distance: nil,
            date: now
        )
        let service = SequencedExerciseWorkoutService(dayResults: [[oldWorkout], [newWorkout]])
        let vm = ExerciseViewModel(workoutService: service)

        let firstLoad = Task { await vm.loadHealthKitWorkouts() }
        await service.waitUntilDayFetchStarts(call: 0)

        let secondLoad = Task { await vm.loadHealthKitWorkouts() }
        await service.waitUntilDayFetchStarts(call: 1)

        await service.resumeDayFetch(call: 1)
        _ = await secondLoad.result

        await service.resumeDayFetch(call: 0)
        _ = await firstLoad.result

        #expect(vm.healthKitWorkouts.map(\.id) == ["new"])
        #expect(vm.isLoading == false)
    }
}

@Suite("ExerciseListItem")
struct ExerciseListItemTests {
    @Test("formattedDuration converts seconds to minutes")
    func formattedDuration() {
        let item = ExerciseListItem(
            id: "1", type: "Running", duration: 1800,
            calories: nil, distance: nil, date: Date(), source: .healthKit
        )
        #expect(item.formattedDuration.hasPrefix("30"))
    }

    @Test("setSummary returns nil when no completed sets")
    func noSets() {
        let item = ExerciseListItem(
            id: "1", type: "Bench Press", duration: 1800,
            calories: nil, distance: nil, date: Date(), source: .manual
        )
        #expect(item.setSummary == nil)
    }

    @Test("setSummary formats set count and reps")
    func setSummaryWithReps() {
        let set1 = WorkoutSet()
        set1.reps = 10
        set1.isCompleted = true

        let set2 = WorkoutSet()
        set2.reps = 8
        set2.isCompleted = true

        let item = ExerciseListItem(
            id: "1", type: "Pull Up", duration: 600,
            calories: nil, distance: nil, date: Date(),
            source: .manual, completedSets: [set1, set2]
        )

        let summary = item.setSummary
        #expect(summary != nil)
        #expect(summary?.contains(String(localized: "\(2.formattedWithSeparator) sets")) == true)
        #expect(summary?.contains(String(localized: "\(18.formattedWithSeparator) reps")) == true)
    }

    @Test("setSummary includes weight range")
    func setSummaryWithWeightRange() {
        let set1 = WorkoutSet()
        set1.weight = 60
        set1.reps = 10
        set1.isCompleted = true

        let set2 = WorkoutSet()
        set2.weight = 65
        set2.reps = 8
        set2.isCompleted = true

        let item = ExerciseListItem(
            id: "1", type: "Bench Press", duration: 1200,
            calories: nil, distance: nil, date: Date(),
            source: .manual, completedSets: [set1, set2]
        )

        let summary = item.setSummary
        #expect(summary != nil)
        #expect(summary?.contains("60") == true)
        #expect(summary?.contains("65") == true)
    }

    @Test("setSummary shows single weight when all same")
    func setSummarySingleWeight() {
        let set1 = WorkoutSet()
        set1.weight = 60
        set1.reps = 10
        set1.isCompleted = true

        let set2 = WorkoutSet()
        set2.weight = 60
        set2.reps = 10
        set2.isCompleted = true

        let item = ExerciseListItem(
            id: "1", type: "Squat", duration: 1200,
            calories: nil, distance: nil, date: Date(),
            source: .manual, completedSets: [set1, set2]
        )

        let summary = item.setSummary
        #expect(summary != nil)
        // Should contain "60kg" once, not a range
        #expect(summary?.contains("60") == true)
        #expect(summary?.contains("-") == false)
    }

    @Test("HealthKit displayName prefers stored workout title")
    func healthKitDisplayNamePrefersStoredWorkoutTitle() {
        let workout = WorkoutSummary(
            id: "HK-BENCH",
            type: "Bench Press",
            activityType: .traditionalStrengthTraining,
            duration: 1800,
            calories: 220,
            distance: nil,
            date: Date()
        )

        let item = ExerciseListItem.fromWorkoutSummary(workout)
        #expect(item.displayName == "Bench Press")
    }

    @Test("HealthKit displayName localizes legacy activity title")
    func healthKitDisplayNameLocalizesLegacyActivityTitle() {
        let workout = WorkoutSummary(
            id: "HK-STRENGTH",
            type: "Strength",
            activityType: .traditionalStrengthTraining,
            duration: 1800,
            calories: 220,
            distance: nil,
            date: Date()
        )

        let item = ExerciseListItem.fromWorkoutSummary(workout)
        #expect(item.displayName == WorkoutActivityType.traditionalStrengthTraining.displayName)
    }
}

@Suite("ExerciseListSection")
struct ExerciseListSectionTests {
    @Test("recentListDedupRecords keeps only records with set data")
    func recentListDedupRecordsFiltersNoSetRecords() {
        let noSetRecord = ExerciseRecord(
            date: Date(),
            exerciseType: "running",
            duration: 300
        )

        let setRecord = ExerciseRecord(
            date: Date(),
            exerciseType: "squat",
            duration: 300
        )
        let set = WorkoutSet(setNumber: 1, reps: 8, isCompleted: true)
        set.exerciseRecord = setRecord
        setRecord.sets = [set]

        let filtered = recentListDedupRecords(from: [noSetRecord, setRecord])
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == setRecord.id)
    }

    @Test("filteringAppDuplicates excludes tombstoned IDs")
    func filteringAppDuplicatesExcludesTombstoned() {
        let now = Date()
        let workouts: [WorkoutSummary] = [
            WorkoutSummary(id: "alive", type: "Running", duration: 1800, calories: 200, distance: nil, date: now),
            WorkoutSummary(id: "dead", type: "Cycling", duration: 3600, calories: 400, distance: nil, date: now),
        ]

        let filtered = workouts.filteringAppDuplicates(
            against: [],
            tombstonedIDs: ["dead"]
        )

        #expect(filtered.count == 1)
        #expect(filtered[0].id == "alive")
    }

    @Test("recent dedup does not hide HealthKit cardio when only no-set manual records exist")
    func recentListDedupDoesNotUseNoSetRecords() {
        let now = Date()
        let noSetRunningRecord = ExerciseRecord(
            date: now,
            exerciseType: WorkoutActivityType.running.rawValue,
            duration: 300
        )

        let workout = WorkoutSummary(
            id: "HK-WATCH-RUNNING",
            type: "Running",
            activityType: .running,
            duration: 300,
            calories: 35,
            distance: 650,
            date: now,
            isFromThisApp: true
        )

        let filteredRecords = recentListDedupRecords(from: [noSetRunningRecord])
        let deduped = [workout].filteringAppDuplicates(against: filteredRecords)

        #expect(deduped.count == 1)
        #expect(deduped.first?.id == "HK-WATCH-RUNNING")
    }
}
