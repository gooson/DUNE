import Foundation
import Testing
@testable import Dailve

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
