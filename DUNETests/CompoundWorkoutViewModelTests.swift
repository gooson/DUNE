import Foundation
import Testing
@testable import DUNE

@Suite("CompoundWorkoutViewModel")
@MainActor
struct CompoundWorkoutViewModelTests {

    private func makeExercise(id: String = "test-1", name: String = "Bench Press") -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: name,
            category: .strength,
            inputType: .setsRepsWeight,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            equipment: .barbell,
            metValue: 6.0
        )
    }

    private func makeConfig(
        exerciseCount: Int = 2,
        rounds: Int = 3,
        rest: Int = 30
    ) -> CompoundWorkoutConfig {
        let exercises = (0..<exerciseCount).map { i in
            makeExercise(id: "ex-\(i)", name: "Exercise \(i)")
        }
        return CompoundWorkoutConfig(
            exercises: exercises,
            mode: exerciseCount >= 3 ? .circuit : .superset,
            totalRounds: rounds,
            restBetweenExercises: rest
        )
    }

    // MARK: - Initialization

    @Test("Init creates one ViewModel per exercise")
    func initCreatesViewModels() {
        let config = makeConfig(exerciseCount: 3)
        let vm = CompoundWorkoutViewModel(config: config)
        #expect(vm.exerciseViewModels.count == 3)
    }

    @Test("Init starts at first exercise, round 1")
    func initStartsAtBeginning() {
        let vm = CompoundWorkoutViewModel(config: makeConfig())
        #expect(vm.currentExerciseIndex == 0)
        #expect(vm.currentRound == 1)
    }

    @Test("Each ViewModel has correct exercise")
    func viewModelExerciseAssignment() {
        let config = makeConfig(exerciseCount: 3)
        let vm = CompoundWorkoutViewModel(config: config)
        for i in config.exercises.indices {
            #expect(vm.exerciseViewModels[i].exercise.id == config.exercises[i].id)
        }
    }

    // MARK: - Navigation

    @Test("advanceToNextExercise moves to next exercise")
    func advanceWithinRound() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 3))
        vm.advanceToNextExercise()
        #expect(vm.currentExerciseIndex == 1)
        #expect(vm.currentRound == 1)
        #expect(vm.isTransitioning == true)
    }

    @Test("advanceToNextExercise wraps to next round")
    func advanceToNextRound() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 2, rounds: 3))
        // Move to second exercise
        vm.advanceToNextExercise()
        vm.finishTransition()
        // Move to next round
        vm.advanceToNextExercise()
        #expect(vm.currentExerciseIndex == 0)
        #expect(vm.currentRound == 2)
    }

    @Test("advanceToNextExercise does nothing at end")
    func advanceAtEnd() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 2, rounds: 1))
        vm.advanceToNextExercise() // Move to exercise 2
        vm.finishTransition()
        // At last exercise of last round — should not change
        vm.advanceToNextExercise()
        #expect(vm.currentExerciseIndex == 1)
        #expect(vm.currentRound == 1)
    }

    @Test("goToExercise navigates correctly")
    func goToExercise() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 3))
        vm.goToExercise(at: 2)
        #expect(vm.currentExerciseIndex == 2)
        #expect(vm.isTransitioning == false)
    }

    @Test("goToExercise ignores invalid index")
    func goToExerciseInvalid() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 2))
        vm.goToExercise(at: 5)
        #expect(vm.currentExerciseIndex == 0)
    }

    @Test("finishTransition clears transitioning state")
    func finishTransition() {
        let vm = CompoundWorkoutViewModel(config: makeConfig())
        vm.advanceToNextExercise()
        #expect(vm.isTransitioning == true)
        vm.finishTransition()
        #expect(vm.isTransitioning == false)
    }

    // MARK: - State Queries

    @Test("isLastExerciseInRound correct")
    func isLastExercise() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 2))
        #expect(vm.isLastExerciseInRound == false)
        vm.advanceToNextExercise()
        #expect(vm.isLastExerciseInRound == true)
    }

    @Test("isComplete at last exercise of last round")
    func isComplete() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 2, rounds: 1))
        #expect(vm.isComplete == false)
        vm.advanceToNextExercise()
        #expect(vm.isComplete == true)
    }

    @Test("roundProgress increases with advancement")
    func roundProgress() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 2, rounds: 2))
        let p0 = vm.roundProgress
        vm.advanceToNextExercise()
        vm.finishTransition()
        let p1 = vm.roundProgress
        #expect(p1 > p0)
    }

    @Test("totalCompletedSets counts across all exercises")
    func totalCompletedSets() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 2))
        #expect(vm.totalCompletedSets == 0)
        // Complete a set in exercise 0
        vm.exerciseViewModels[0].sets[0].reps = "10"
        vm.exerciseViewModels[0].sets[0].weight = "100"
        _ = vm.exerciseViewModels[0].toggleSetCompletion(at: 0)
        #expect(vm.totalCompletedSets == 1)
    }

    // MARK: - Record Creation

    @Test("createAllRecords returns empty when no completed sets")
    func createAllRecordsEmpty() {
        let vm = CompoundWorkoutViewModel(config: makeConfig())
        let records = vm.createAllRecords()
        #expect(records.isEmpty)
        #expect(vm.validationError != nil)
    }

    @Test("createAllRecords returns records for completed exercises")
    func createAllRecordsWithData() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 2))
        // Complete a set in first exercise
        vm.exerciseViewModels[0].sets[0].reps = "10"
        vm.exerciseViewModels[0].sets[0].weight = "100"
        _ = vm.exerciseViewModels[0].toggleSetCompletion(at: 0)

        let records = vm.createAllRecords()
        #expect(records.count == 1)
    }

    @Test("isSaving prevents duplicate record creation")
    func isSavingGuard() {
        let vm = CompoundWorkoutViewModel(config: makeConfig())
        vm.isSaving = true
        let records = vm.createAllRecords()
        #expect(records.isEmpty)
    }

    // MARK: - Round Advancement Adds Sets

    @Test("Advancing to next round adds a set to each exercise")
    func nextRoundAddsSets() {
        let vm = CompoundWorkoutViewModel(config: makeConfig(exerciseCount: 2, rounds: 2))
        let initialSetCount = vm.exerciseViewModels[0].sets.count
        // Advance through all exercises in round 1
        vm.advanceToNextExercise() // move to ex 1
        vm.finishTransition()
        vm.advanceToNextExercise() // move to round 2, ex 0
        #expect(vm.exerciseViewModels[0].sets.count == initialSetCount + 1)
        #expect(vm.exerciseViewModels[1].sets.count == initialSetCount + 1)
    }
}
