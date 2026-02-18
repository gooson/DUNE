import Foundation
import Testing
@testable import Dailve

@Suite("WorkoutSessionViewModel")
@MainActor
struct WorkoutSessionViewModelTests {
    // Helper to create a test exercise definition
    private func makeExercise(
        inputType: ExerciseInputType = .setsRepsWeight,
        metValue: Double = 6.0
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: "test-bench-press",
            name: "Bench Press",
            localizedName: "벤치프레스",
            category: .strength,
            inputType: inputType,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps, .shoulders],
            equipment: .barbell,
            metValue: metValue
        )
    }

    @Test("Initial state has default number of empty sets")
    func initialState() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)

        #expect(vm.sets.count == WorkoutSessionViewModel.defaultSetCount)
        #expect(vm.sets[0].setNumber == 1)
        #expect(vm.sets[0].weight.isEmpty)
        #expect(vm.sets[0].reps.isEmpty)
        #expect(vm.sets.last?.setNumber == WorkoutSessionViewModel.defaultSetCount)
    }

    @Test("addSet increments set number")
    func addSet() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        let initialCount = vm.sets.count

        vm.addSet()
        #expect(vm.sets.count == initialCount + 1)
        #expect(vm.sets.last?.setNumber == initialCount + 1)
    }

    @Test("removeSet at valid index")
    func removeSet() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        let initialCount = vm.sets.count

        vm.removeSet(at: 1)
        #expect(vm.sets.count == initialCount - 1)
        // Set numbers should be renumbered
        for (i, set) in vm.sets.enumerated() {
            #expect(set.setNumber == i + 1)
        }
    }

    @Test("removeSet ignores invalid index")
    func removeSetInvalidIndex() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        let initialCount = vm.sets.count

        vm.removeSet(at: 100)
        #expect(vm.sets.count == initialCount)
    }

    @Test("toggleSetCompletion changes isCompleted")
    func toggleCompletion() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)

        #expect(!vm.sets[0].isCompleted)
        let first = vm.toggleSetCompletion(at: 0)
        #expect(first == true)
        #expect(vm.sets[0].isCompleted)
        let second = vm.toggleSetCompletion(at: 0)
        #expect(second == false)
        #expect(!vm.sets[0].isCompleted)
    }

    @Test("createValidatedRecord returns nil with no completed sets")
    func noCompletedSets() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        // Not completed

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord succeeds with valid completed set")
    func validRecord() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.exerciseType == "Bench Press")
        #expect(record?.exerciseDefinitionID == "test-bench-press")
        #expect(record?.completedSets.count == 1)
    }

    @Test("createValidatedRecord rejects reps > 1000")
    func repsOverLimit() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].reps = "1500"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord rejects weight > 500")
    func weightOverLimit() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "600"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("isSaving prevents duplicate record creation")
    func isSavingGuard() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true
        vm.isSaving = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
    }

    @Test("Calorie estimation uses injected service")
    func calorieEstimation() {
        struct MockCalorieService: CalorieEstimating {
            func estimate(metValue: Double, bodyWeightKg: Double, durationSeconds: TimeInterval, restSeconds: TimeInterval) -> Double? {
                return 250.0
            }
        }

        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise, calorieService: MockCalorieService())
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.estimatedCalories == 250.0)
    }

    @Test("Exercise input type is passed through")
    func inputType() {
        let exercise = makeExercise(inputType: .setsReps)
        let vm = WorkoutSessionViewModel(exercise: exercise)

        #expect(vm.exercise.inputType == .setsReps)
    }

    @Test("Memo is included in record")
    func memoIncluded() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true
        vm.memo = "Good session"

        let record = vm.createValidatedRecord()
        #expect(record?.memo == "Good session")
    }

    @Test("createValidatedRecord rejects duration > 500 for durationDistance")
    func durationOverLimit() {
        let exercise = makeExercise(inputType: .durationDistance)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "600"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord rejects distance > 500 for durationDistance")
    func distanceOverLimit() {
        let exercise = makeExercise(inputType: .durationDistance)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].distance = "600"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord succeeds with valid durationDistance set")
    func validDurationDistance() {
        let exercise = makeExercise(inputType: .durationDistance)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].distance = "5.0"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        // Duration stored in seconds: 30 min * 60 = 1800
        let setDuration = record?.completedSets.first?.duration
        #expect(setDuration == 1800.0)
    }

    @Test("createValidatedRecord validates duration for durationIntensity")
    func durationIntensityValidation() {
        let exercise = makeExercise(inputType: .durationIntensity)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "0"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord rejects intensity > 10")
    func intensityOverLimit() {
        let exercise = makeExercise(inputType: .durationIntensity)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].intensity = "15"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord persists intensity value")
    func intensityPersisted() {
        let exercise = makeExercise(inputType: .durationIntensity)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].intensity = "7"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.intensity == 7)
    }

    @Test("createValidatedRecord validates roundsBased input")
    func roundsBasedValidation() {
        let exercise = makeExercise(inputType: .roundsBased)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].reps = "0"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }
}
