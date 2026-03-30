import Testing
@testable import DUNE

@Suite("Template Workout Skip And Advance")
struct TemplateWorkoutSkipTests {

    // MARK: - Helpers

    private static func makeExercise(name: String) -> ExerciseDefinition {
        ExerciseDefinition(
            id: name.lowercased(),
            name: name,
            localizedName: name,
            category: .strength,
            inputType: .setsRepsWeight,
            primaryMuscles: [.chest],
            secondaryMuscles: [],
            equipment: .barbell,
            metValue: 6.0,
            aliases: nil,
            difficulty: nil,
            tags: nil,
            description: nil,
            customCategoryName: nil,
            cardioSecondaryUnit: nil
        )
    }

    private static func makeEntry(name: String) -> TemplateEntry {
        TemplateEntry(
            exerciseDefinitionID: name.lowercased(),
            exerciseName: name,
            defaultSets: 3,
            defaultReps: 10
        )
    }

    private static func makeConfig(exerciseNames: [String]) -> TemplateWorkoutConfig {
        TemplateWorkoutConfig(
            templateName: "Test Template",
            exercises: exerciseNames.map { makeExercise(name: $0) },
            templateEntries: exerciseNames.map { makeEntry(name: $0) }
        )
    }

    // MARK: - skipAndAdvance Tests

    @Test("skipAndAdvance moves to next pending exercise")
    @MainActor
    func skipAndAdvance_movesToNextPending() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig(exerciseNames: ["A", "B", "C"]))

        // A is inProgress, skip it
        let hasNext = vm.skipAndAdvance()

        #expect(hasNext == true)
        #expect(vm.currentExerciseIndex == 1)
        #expect(vm.exerciseStatuses[0] == .skipped)
        #expect(vm.exerciseStatuses[1] == .inProgress)
        #expect(vm.exerciseStatuses[2] == .pending)
    }

    @Test("skipAndAdvance returns false when all exercises are skipped")
    @MainActor
    func skipAndAdvance_allSkipped_returnsFalse() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig(exerciseNames: ["A", "B"]))

        // Skip A -> B proposed
        let hasB = vm.skipAndAdvance()
        #expect(hasB == true)
        #expect(vm.currentExerciseIndex == 1)

        // Skip B -> no more
        let hasMore = vm.skipAndAdvance()
        #expect(hasMore == false)
        #expect(vm.exerciseStatuses[0] == .skipped)
        #expect(vm.exerciseStatuses[1] == .skipped)
        #expect(vm.isAllDone == true)
    }

    @Test("skipAndAdvance skips middle exercise and proposes next")
    @MainActor
    func skipAndAdvance_middleSkipped_skipsToNext() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig(exerciseNames: ["A", "B", "C"]))

        // Complete A by marking it completed manually
        vm.exerciseStatuses[0] = .completed
        vm.currentExerciseIndex = 1
        vm.exerciseStatuses[1] = .inProgress

        // Skip B -> C should be proposed
        let hasC = vm.skipAndAdvance()

        #expect(hasC == true)
        #expect(vm.currentExerciseIndex == 2)
        #expect(vm.exerciseStatuses[0] == .completed)
        #expect(vm.exerciseStatuses[1] == .skipped)
        #expect(vm.exerciseStatuses[2] == .inProgress)
    }

    @Test("skipAndAdvance preserves completed exercise status")
    @MainActor
    func skipAndAdvance_preservesCompletedStatus() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig(exerciseNames: ["A", "B", "C"]))

        // Complete A
        vm.exerciseStatuses[0] = .completed
        vm.currentExerciseIndex = 1
        vm.exerciseStatuses[1] = .inProgress

        // Skip B
        _ = vm.skipAndAdvance()

        // Skip C
        let hasMore = vm.skipAndAdvance()

        #expect(hasMore == false)
        #expect(vm.exerciseStatuses[0] == .completed)
        #expect(vm.hasAnyCompleted == true)
        #expect(vm.isAllDone == true)
    }

    @Test("skipAndAdvance on single exercise returns false")
    @MainActor
    func skipAndAdvance_singleExercise_returnsFalse() {
        let vm = TemplateWorkoutViewModel(config: Self.makeConfig(exerciseNames: ["A"]))

        let hasMore = vm.skipAndAdvance()

        #expect(hasMore == false)
        #expect(vm.exerciseStatuses[0] == .skipped)
        #expect(vm.isAllDone == true)
    }
}
