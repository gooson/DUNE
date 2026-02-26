import Foundation
import Testing
@testable import DUNE

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
}

@Suite("ExerciseListItem")
struct ExerciseListItemTests {
    @Test("formattedDuration converts seconds to minutes")
    func formattedDuration() {
        let item = ExerciseListItem(
            id: "1", type: "Running", duration: 1800,
            calories: nil, distance: nil, date: Date(), source: .healthKit
        )
        #expect(item.formattedDuration == "30 min")
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
        #expect(summary?.contains("2 sets") == true)
        #expect(summary?.contains("18 reps") == true)
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
}
