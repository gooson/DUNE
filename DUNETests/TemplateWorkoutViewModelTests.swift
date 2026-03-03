import Testing
@testable import DUNE

@Suite("TemplateWorkoutViewModel")
@MainActor
struct TemplateWorkoutViewModelTests {

    // MARK: - Test Helpers

    private static func makeExercise(
        id: String = "bench-press",
        name: String = "Bench Press",
        inputType: ExerciseInputType = .setsRepsWeight
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: name,
            category: .strength,
            inputType: inputType,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            equipment: .barbell,
            metValue: 5.0
        )
    }

    private static func makeEntry(
        exerciseID: String = "bench-press",
        name: String = "Bench Press",
        sets: Int = 3,
        reps: Int = 10,
        weight: Double? = 80
    ) -> TemplateEntry {
        TemplateEntry(
            exerciseDefinitionID: exerciseID,
            exerciseName: name,
            defaultSets: sets,
            defaultReps: reps,
            defaultWeightKg: weight
        )
    }

    private static func makeConfig(count: Int = 3) -> TemplateWorkoutConfig {
        let exercises = [
            makeExercise(id: "bench-press", name: "Bench Press"),
            makeExercise(id: "shoulder-press", name: "Shoulder Press"),
            makeExercise(id: "lateral-raise", name: "Lateral Raise", inputType: .setsReps)
        ]
        let entries = [
            makeEntry(exerciseID: "bench-press", name: "Bench Press", sets: 3, reps: 10, weight: 80),
            makeEntry(exerciseID: "shoulder-press", name: "Shoulder Press", sets: 3, reps: 8, weight: 40),
            makeEntry(exerciseID: "lateral-raise", name: "Lateral Raise", sets: 2, reps: 15, weight: nil)
        ]
        return TemplateWorkoutConfig(
            templateName: "Push Day",
            exercises: Array(exercises.prefix(count)),
            templateEntries: Array(entries.prefix(count))
        )
    }

    // MARK: - Initialization Tests

    @Test("Init creates correct number of exercise VMs")
    func initCreatesViewModels() {
        let config = Self.makeConfig(count: 3)
        let vm = TemplateWorkoutViewModel(config: config)
        #expect(vm.exerciseViewModels.count == 3)
        #expect(vm.exerciseStatuses.count == 3)
    }

    @Test("Init sets first exercise as in-progress")
    func initSetsFirstInProgress() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        #expect(vm.exerciseStatuses[0] == .inProgress)
        #expect(vm.exerciseStatuses[1] == .pending)
        #expect(vm.exerciseStatuses[2] == .pending)
        #expect(vm.currentExerciseIndex == 0)
    }

    @Test("Init adjusts set counts, prefill populates values")
    func initPrefillsDefaults() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())

        // Init adjusts set counts from template defaults
        #expect(vm.exerciseViewModels[0].sets.count == 3)
        #expect(vm.exerciseViewModels[1].sets.count == 3)
        #expect(vm.exerciseViewModels[2].sets.count == 2)

        // Prefill with kg unit
        vm.prefillFromTemplateDefaults(weightUnit: .kg)

        // Bench Press: reps=10, weight=80 (kg)
        let benchVM = vm.exerciseViewModels[0]
        #expect(benchVM.sets[0].reps == "10")
        #expect(benchVM.sets[0].weight == "80")

        // Shoulder Press: reps=8, weight=40 (kg)
        let ohpVM = vm.exerciseViewModels[1]
        #expect(ohpVM.sets[0].reps == "8")
        #expect(ohpVM.sets[0].weight == "40")

        // Lateral Raise: reps=15, no weight
        let raiseVM = vm.exerciseViewModels[2]
        #expect(raiseVM.sets[0].reps == "15")
        #expect(raiseVM.sets[0].weight == "")
    }

    @Test("Prefill converts weight to display unit (lb)")
    func prefillConvertsWeightUnit() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.prefillFromTemplateDefaults(weightUnit: .lb)

        // 80 kg → ~176.4 lb
        let benchWeight = vm.exerciseViewModels[0].sets[0].weight
        let parsedWeight = Double(benchWeight) ?? 0
        #expect(parsedWeight > 175 && parsedWeight < 178)

        // 40 kg → ~88.2 lb
        let ohpWeight = vm.exerciseViewModels[1].sets[0].weight
        let parsedOHP = Double(ohpWeight) ?? 0
        #expect(parsedOHP > 87 && parsedOHP < 90)
    }

    // MARK: - Navigation Tests

    @Test("advanceToNext moves to next pending exercise")
    func advanceToNext() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.exerciseStatuses[0] = .completed
        vm.advanceToNext()
        #expect(vm.currentExerciseIndex == 1)
        #expect(vm.exerciseStatuses[1] == .inProgress)
    }

    @Test("advanceToNext skips completed exercises")
    func advanceSkipsCompleted() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.exerciseStatuses[0] = .completed
        vm.exerciseStatuses[1] = .completed
        vm.advanceToNext()
        #expect(vm.currentExerciseIndex == 2)
        #expect(vm.exerciseStatuses[2] == .inProgress)
    }

    @Test("skipCurrent marks exercise as skipped and advances")
    func skipCurrent() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.skipCurrent()
        #expect(vm.exerciseStatuses[0] == .skipped)
        #expect(vm.currentExerciseIndex == 1)
        #expect(vm.exerciseStatuses[1] == .inProgress)
    }

    @Test("goToExercise allows jumping to pending exercise")
    func goToExercise() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.goToExercise(at: 2)
        #expect(vm.currentExerciseIndex == 2)
        #expect(vm.exerciseStatuses[2] == .inProgress)
    }

    @Test("goToExercise ignores completed exercises")
    func goToExerciseIgnoresCompleted() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.exerciseStatuses[2] = .completed
        let originalIndex = vm.currentExerciseIndex
        vm.goToExercise(at: 2)
        #expect(vm.currentExerciseIndex == originalIndex)
    }

    @Test("goToExercise allows re-doing skipped exercises")
    func goToSkippedExercise() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.exerciseStatuses[1] = .skipped
        vm.goToExercise(at: 1)
        #expect(vm.currentExerciseIndex == 1)
        #expect(vm.exerciseStatuses[1] == .inProgress)
    }

    // MARK: - Completion Tests

    @Test("isAllDone is true when all exercises are completed or skipped")
    func isAllDone() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.exerciseStatuses[0] = .completed
        vm.exerciseStatuses[1] = .completed
        vm.exerciseStatuses[2] = .skipped
        #expect(vm.isAllDone == true)
    }

    @Test("isAllDone is false when any exercise is pending")
    func isNotAllDone() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.exerciseStatuses[0] = .completed
        vm.exerciseStatuses[1] = .completed
        #expect(vm.isAllDone == false)
    }

    @Test("hasAnyCompleted is true when at least one exercise is completed")
    func hasAnyCompleted() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.exerciseStatuses[0] = .completed
        #expect(vm.hasAnyCompleted == true)
    }

    @Test("hasAnyCompleted is false when only skipped")
    func hasNoCompleted() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.exerciseStatuses[0] = .skipped
        vm.exerciseStatuses[1] = .skipped
        vm.exerciseStatuses[2] = .skipped
        #expect(vm.hasAnyCompleted == false)
    }

    @Test("completedCount reflects actual completed count")
    func completedCount() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.exerciseStatuses[0] = .completed
        vm.exerciseStatuses[1] = .skipped
        vm.exerciseStatuses[2] = .completed
        #expect(vm.completedCount == 2)
    }

    // MARK: - Record Creation Tests

    @Test("createRecordForCurrent fails with no completed sets")
    func createRecordFailsEmpty() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        let record = vm.createRecordForCurrent()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createRecordForCurrent succeeds with completed sets")
    func createRecordSucceeds() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        let currentVM = vm.currentViewModel
        currentVM.sets[0].isCompleted = true
        currentVM.sets[0].weight = "80"
        currentVM.sets[0].reps = "10"

        let record = vm.createRecordForCurrent()
        #expect(record != nil)
        #expect(record?.exerciseType == "Bench Press")
        // Status is NOT .completed yet — deferred until didFinishSaving
        #expect(vm.isSaving == true)
        #expect(vm.exerciseStatuses[0] == .inProgress)

        vm.didFinishSaving()
        // NOW it's completed
        #expect(vm.exerciseStatuses[0] == .completed)
        #expect(vm.isSaving == false)
    }

    @Test("createRecordForCurrent prevents double save")
    func preventDoubleSave() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        let currentVM = vm.currentViewModel
        currentVM.sets[0].isCompleted = true
        currentVM.sets[0].weight = "80"
        currentVM.sets[0].reps = "10"

        _ = vm.createRecordForCurrent()
        // Second call should return nil (isSaving is true)
        let second = vm.createRecordForCurrent()
        #expect(second == nil)
        vm.didFinishSaving()
    }

    // MARK: - Edge Cases

    @Test("Skip all exercises results in isAllDone")
    func skipAllExercises() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.skipCurrent() // skip 0, advance to 1
        vm.skipCurrent() // skip 1, advance to 2
        vm.skipCurrent() // skip 2, no more pending
        #expect(vm.isAllDone == true)
        #expect(vm.hasAnyCompleted == false)
    }

    @Test("advanceToNext wraps around to find pending exercise")
    func advanceWrapsAround() {
        let config = Self.makeConfig()
        let vm = TemplateWorkoutViewModel(config: config)
        // Complete exercise 0, skip to exercise 2 (skip exercise 1)
        vm.exerciseStatuses[0] = .completed
        vm.exerciseStatuses[2] = .completed
        vm.currentExerciseIndex = 2
        vm.advanceToNext()
        // Should wrap to exercise 1
        #expect(vm.currentExerciseIndex == 1)
    }

    @Test("totalCompletedSets aggregates across all exercises")
    func totalCompletedSets() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        // Complete 2 sets in exercise 0
        vm.exerciseViewModels[0].sets[0].isCompleted = true
        vm.exerciseViewModels[0].sets[1].isCompleted = true
        // Complete 1 set in exercise 1
        vm.exerciseViewModels[1].sets[0].isCompleted = true
        #expect(vm.totalCompletedSets == 3)
    }

    @Test("goToExercise with out-of-bounds index is no-op")
    func goToExerciseOutOfBounds() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig())
        vm.goToExercise(at: 99)
        #expect(vm.currentExerciseIndex == 0)
    }
}
