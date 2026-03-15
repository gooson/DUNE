import Foundation
import Testing
@testable import DUNE

@Suite("TemplateWorkoutConfig")
struct TemplateWorkoutConfigTests {

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

    private func makeEntry(
        id: String = "test-1",
        name: String = "Bench Press",
        sets: Int = 3,
        reps: Int = 10,
        weight: Double? = 60.0
    ) -> TemplateEntry {
        TemplateEntry(
            exerciseDefinitionID: id,
            exerciseName: name,
            defaultSets: sets,
            defaultReps: reps,
            defaultWeightKg: weight
        )
    }

    @Test("Config stores template name and exercises")
    func configStoresData() {
        let exercises = [
            makeExercise(id: "ex-1", name: "Bench Press"),
            makeExercise(id: "ex-2", name: "Squat")
        ]
        let entries = [
            makeEntry(id: "ex-1", name: "Bench Press"),
            makeEntry(id: "ex-2", name: "Squat")
        ]
        let config = TemplateWorkoutConfig(
            templateName: "Push Day",
            exercises: exercises,
            templateEntries: entries
        )
        #expect(config.templateName == "Push Day")
        #expect(config.exercises.count == 2)
        #expect(config.templateEntries.count == 2)
    }

    @Test("Config has unique ID")
    func configHasUniqueID() {
        let exercises = [makeExercise()]
        let entries = [makeEntry()]
        let config1 = TemplateWorkoutConfig(templateName: "A", exercises: exercises, templateEntries: entries)
        let config2 = TemplateWorkoutConfig(templateName: "A", exercises: exercises, templateEntries: entries)
        #expect(config1.id != config2.id)
    }
}

@Suite("TemplateExerciseInfo")
struct TemplateExerciseInfoTests {

    @Test("Info tracks exercise progress")
    func infoTracksProgress() {
        let info = TemplateExerciseInfo(
            exerciseNumber: 2,
            totalExercises: 5,
            nextExerciseName: "Squat",
            templateName: "Push Day"
        )
        #expect(info.exerciseNumber == 2)
        #expect(info.totalExercises == 5)
        #expect(info.nextExerciseName == "Squat")
        #expect(info.templateName == "Push Day")
    }

    @Test("Last exercise has nil nextExerciseName")
    func lastExerciseHasNilNext() {
        let info = TemplateExerciseInfo(
            exerciseNumber: 3,
            totalExercises: 3,
            nextExerciseName: nil,
            templateName: "Leg Day"
        )
        #expect(info.nextExerciseName == nil)
    }
}

@Suite("WorkoutSessionViewModel defaultSetCount")
@MainActor
struct WorkoutSessionViewModelDefaultSetCountTests {

    private func makeExercise() -> ExerciseDefinition {
        ExerciseDefinition(
            id: "test",
            name: "Test",
            localizedName: "Test",
            category: .strength,
            inputType: .setsRepsWeight,
            primaryMuscles: [],
            secondaryMuscles: [],
            equipment: .barbell,
            metValue: 5.0
        )
    }

    @Test("Default init uses WorkoutDefaults.setCount")
    func defaultInit() {
        let vm = WorkoutSessionViewModel(exercise: makeExercise())
        #expect(vm.sets.count == WorkoutDefaults.setCount)
    }

    @Test("Custom defaultSetCount overrides default")
    func customSetCount() {
        let vm = WorkoutSessionViewModel(exercise: makeExercise(), defaultSetCount: 5)
        #expect(vm.sets.count == 5)
    }

    @Test("defaultSetCount of 1 creates single set")
    func singleSet() {
        let vm = WorkoutSessionViewModel(exercise: makeExercise(), defaultSetCount: 1)
        #expect(vm.sets.count == 1)
    }

    @Test("nil defaultSetCount falls back to default")
    func nilFallsBack() {
        let vm = WorkoutSessionViewModel(exercise: makeExercise(), defaultSetCount: nil)
        #expect(vm.sets.count == WorkoutDefaults.setCount)
    }
}

@Suite("TemplateWorkoutViewModel Reorder")
@MainActor
struct TemplateWorkoutViewModelReorderTests {

    private func makeExercise(id: String, name: String) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: name,
            category: .strength,
            inputType: .setsRepsWeight,
            primaryMuscles: [.chest],
            secondaryMuscles: [],
            equipment: .barbell,
            metValue: 6.0
        )
    }

    private func makeEntry(id: String, name: String) -> TemplateEntry {
        TemplateEntry(
            exerciseDefinitionID: id,
            exerciseName: name,
            defaultSets: 3,
            defaultReps: 10,
            defaultWeightKg: nil
        )
    }

    private func makeViewModel(count: Int = 3) -> TemplateWorkoutViewModel {
        let names = ["Bench Press", "Squat", "Deadlift", "OHP", "Row"]
        let exercises = (0..<count).map { i in
            makeExercise(id: "ex-\(i)", name: names[i])
        }
        let entries = (0..<count).map { i in
            makeEntry(id: "ex-\(i)", name: names[i])
        }
        let config = TemplateWorkoutConfig(
            templateName: "Test",
            exercises: exercises,
            templateEntries: entries
        )
        return TemplateWorkoutViewModel(config: config)
    }

    @Test("moveExercise swaps two exercises")
    func moveSwapsTwo() {
        let vm = makeViewModel()
        // Move index 2 (Deadlift) to index 0
        vm.moveExercise(from: IndexSet(integer: 2), to: 0)

        #expect(vm.exercises[0].name == "Deadlift")
        #expect(vm.exercises[1].name == "Bench Press")
        #expect(vm.exercises[2].name == "Squat")
    }

    @Test("moveExercise keeps all parallel arrays in sync")
    func moveKeepsArraysInSync() {
        let vm = makeViewModel()
        vm.moveExercise(from: IndexSet(integer: 0), to: 3)

        // exercises, templateEntries, exerciseViewModels should all match
        for i in vm.exercises.indices {
            #expect(vm.exercises[i].id == vm.templateEntries[i].exerciseDefinitionID)
        }
        #expect(vm.exercises.count == vm.exerciseViewModels.count)
        #expect(vm.exercises.count == vm.exerciseStatuses.count)
    }

    @Test("moveExercise tracks currentExerciseIndex")
    func moveTracksCurrent() {
        let vm = makeViewModel()
        // Current is index 0 (Bench Press, inProgress)
        #expect(vm.currentExerciseIndex == 0)
        #expect(vm.currentExercise.name == "Bench Press")

        // Move Bench Press from 0 to end
        vm.moveExercise(from: IndexSet(integer: 0), to: 3)

        // currentExerciseIndex should follow Bench Press to its new position
        #expect(vm.currentExercise.name == "Bench Press")
        #expect(vm.currentExerciseIndex == 2)
    }

    @Test("moveExercise preserves completed status")
    func movePreservesCompleted() {
        let vm = makeViewModel()
        vm.exerciseStatuses[1] = .completed

        // Move completed exercise
        vm.moveExercise(from: IndexSet(integer: 1), to: 0)

        #expect(vm.exerciseStatuses[0] == .completed)
        #expect(vm.exercises[0].name == "Squat")
    }

    @Test("canReorderExercises requires 2+ non-completed")
    func canReorderRequiresTwo() {
        let vm = makeViewModel(count: 2)
        #expect(vm.canReorderExercises == true)

        vm.exerciseStatuses[0] = .completed
        #expect(vm.canReorderExercises == false)
    }

    @Test("canReorderExercises with all completed")
    func canReorderAllCompleted() {
        let vm = makeViewModel()
        for i in vm.exerciseStatuses.indices {
            vm.exerciseStatuses[i] = .completed
        }
        #expect(vm.canReorderExercises == false)
    }

    @Test("config remains unchanged after reorder")
    func configUnchanged() {
        let vm = makeViewModel()
        let originalFirstID = vm.config.exercises[0].id

        vm.moveExercise(from: IndexSet(integer: 0), to: 3)

        #expect(vm.config.exercises[0].id == originalFirstID)
    }
}
