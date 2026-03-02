import Foundation
import Testing
@testable import DUNE

@Suite("CardioSessionViewModel")
@MainActor
struct CardioSessionViewModelTests {

    // MARK: - Helpers

    private func makeExercise(
        id: String = "running",
        name: String = "Running",
        cardioSecondaryUnit: CardioSecondaryUnit = .km
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: "러닝",
            category: .cardio,
            inputType: .durationDistance,
            primaryMuscles: [.quadriceps, .hamstrings],
            secondaryMuscles: [.calves],
            equipment: .none,
            metValue: 9.8,
            cardioSecondaryUnit: cardioSecondaryUnit
        )
    }

    // MARK: - Record Creation

    @Test("createValidatedRecord returns nil when isSaving is true")
    func preventDuplicateSave() {
        let vm = CardioSessionViewModel(exercise: makeExercise(), isOutdoor: true)
        vm.isSaving = true
        let result = vm.createValidatedRecord()
        #expect(result == nil)
    }

    @Test("createValidatedRecord returns nil with zero elapsed time")
    func noDataToSave() {
        let vm = CardioSessionViewModel(exercise: makeExercise(), isOutdoor: true)
        // sessionManager has no startDate → elapsedTime == 0
        let result = vm.createValidatedRecord()
        #expect(result == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord sets isSaving after success")
    func savingFlagSet() {
        let vm = CardioSessionViewModel(exercise: makeExercise(), isOutdoor: true)
        // Manually set startDate on session manager to simulate a session
        vm.sessionManager.testSetStartDate(Date().addingTimeInterval(-300))

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(vm.isSaving == true)
    }

    @Test("didFinishSaving resets isSaving flag")
    func didFinishSavingResetsFlag() {
        let vm = CardioSessionViewModel(exercise: makeExercise(), isOutdoor: true)
        vm.isSaving = true
        vm.didFinishSaving()
        #expect(vm.isSaving == false)
    }

    @Test("Record has correct exerciseDefinitionID")
    func recordExerciseID() {
        let vm = CardioSessionViewModel(exercise: makeExercise(id: "cycling"), isOutdoor: true)
        vm.sessionManager.testSetStartDate(Date().addingTimeInterval(-600))

        let record = vm.createValidatedRecord()
        #expect(record?.exerciseDefinitionID == "cycling")
    }

    @Test("Record duration matches elapsed time")
    func recordDuration() {
        let vm = CardioSessionViewModel(exercise: makeExercise(), isOutdoor: false)
        let start = Date().addingTimeInterval(-1800) // 30 min ago
        vm.sessionManager.testSetStartDate(start)

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        // Duration should be approximately 1800 seconds (allow 2s tolerance)
        let duration = record?.duration ?? 0
        #expect(duration > 1798)
        #expect(duration < 1802)
    }

    @Test("Record distance is nil when no GPS distance")
    func zeroDistanceIsNil() {
        let vm = CardioSessionViewModel(exercise: makeExercise(), isOutdoor: false)
        vm.sessionManager.testSetStartDate(Date().addingTimeInterval(-60))
        // distance is 0 by default

        let record = vm.createValidatedRecord()
        #expect(record?.distance == nil)
    }

    @Test("Record has single WorkoutSet")
    func singleWorkoutSet() {
        let vm = CardioSessionViewModel(exercise: makeExercise(), isOutdoor: true)
        vm.sessionManager.testSetStartDate(Date().addingTimeInterval(-120))

        let record = vm.createValidatedRecord()
        let sets = record?.sets ?? []
        #expect(sets.count == 1)
        #expect(sets.first?.setNumber == 1)
        #expect(sets.first?.isCompleted == true)
    }

    @Test("Record preserves primary muscles from exercise")
    func musclePreservation() {
        let vm = CardioSessionViewModel(exercise: makeExercise(), isOutdoor: true)
        vm.sessionManager.testSetStartDate(Date().addingTimeInterval(-60))

        let record = vm.createValidatedRecord()
        #expect(record?.primaryMuscles.contains(.quadriceps) == true)
        #expect(record?.secondaryMuscles.contains(.calves) == true)
    }

    @Test("cleanup resets session manager")
    func cleanupResetsManager() {
        let vm = CardioSessionViewModel(exercise: makeExercise(), isOutdoor: true)
        vm.sessionManager.testSetStartDate(Date())
        vm.cleanup()
        #expect(vm.sessionManager.state == .idle)
        #expect(vm.sessionManager.startDate == nil)
    }
}
