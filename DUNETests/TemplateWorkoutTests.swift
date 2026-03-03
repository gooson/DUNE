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
