import Foundation
import Testing
@testable import DUNE

private struct MockVisionVoiceWorkoutLibrary: ExerciseLibraryQuerying {
    let exercises: [ExerciseDefinition]

    func allExercises() -> [ExerciseDefinition] {
        exercises
    }

    func exercise(byID id: String) -> ExerciseDefinition? {
        exercises.first { $0.id == id }
    }

    func search(query: String) -> [ExerciseDefinition] {
        []
    }

    func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition] {
        []
    }

    func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition] {
        []
    }

    func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition] {
        []
    }
}

@Suite("VisionVoiceWorkoutCommandParser")
struct VisionVoiceWorkoutCommandParserTests {
    @Test("Parses Korean strength command with explicit weight and reps")
    func parsesKoreanStrengthCommand() {
        let parser = makeParser()

        let result = parser.parse("벤치프레스 80kg 8회")

        guard case .success(let draft) = result else {
            Issue.record("Expected strength draft to parse successfully")
            return
        }

        #expect(draft.exercise.id == "barbell-bench-press")
        #expect(draft.weight == 80)
        #expect(draft.weightUnit == .kg)
        #expect(draft.reps == 8)
        #expect(draft.durationSeconds == nil)
        #expect(draft.distance == nil)
    }

    @Test("Parses English strength command with pound unit")
    func parsesEnglishPoundStrengthCommand() {
        let parser = makeParser()

        let result = parser.parse("Bench Press 176 lb 8 reps")

        guard case .success(let draft) = result else {
            Issue.record("Expected English strength draft to parse successfully")
            return
        }

        #expect(draft.exercise.id == "barbell-bench-press")
        #expect(draft.weight == 176)
        #expect(draft.weightUnit == .lb)
        #expect(draft.reps == 8)
    }

    @Test("Infers strength metrics when units are omitted")
    func infersStrengthMetricsWithoutUnits() {
        let parser = makeParser()

        let result = parser.parse("Squat 100 5")

        guard case .success(let draft) = result else {
            Issue.record("Expected unit-less strength draft to parse successfully")
            return
        }

        #expect(draft.exercise.id == "barbell-squat")
        #expect(draft.weight == 100)
        #expect(draft.weightUnit == .kg)
        #expect(draft.reps == 5)
        #expect(draft.notes.contains("Weight unit was assumed as kg for this draft."))
    }

    @Test("Parses cardio command with duration and distance")
    func parsesCardioCommand() {
        let parser = makeParser()

        let result = parser.parse("러닝 30분 5km")

        guard case .success(let draft) = result else {
            Issue.record("Expected cardio draft to parse successfully")
            return
        }

        #expect(draft.exercise.id == "running")
        #expect(draft.durationSeconds == 1_800)
        #expect(draft.distance == 5)
        #expect(draft.distanceUnit == .km)
        #expect(draft.reps == nil)
    }

    @Test("Fails when the command does not contain an exercise")
    func failsWithoutExerciseName() {
        let parser = makeParser()

        let result = parser.parse("80kg 8회")

        guard case .failure(let message) = result else {
            Issue.record("Expected parser failure when no exercise is present")
            return
        }

        #expect(message == "Add an exercise name to the transcript first.")
    }

    @Test("Fails when a strength command is missing reps")
    func failsWhenStrengthCommandIsMissingReps() {
        let parser = makeParser()

        let result = parser.parse("Bench Press 80kg")

        guard case .failure(let message) = result else {
            Issue.record("Expected parser failure when reps are missing")
            return
        }

        #expect(message == "Add reps for this exercise draft.")
    }

    private func makeParser() -> VisionVoiceWorkoutCommandParser {
        VisionVoiceWorkoutCommandParser(
            library: MockVisionVoiceWorkoutLibrary(
                exercises: [
                    makeExercise(
                        id: "barbell-bench-press",
                        name: "Barbell Bench Press",
                        localizedName: "바벨 벤치프레스",
                        aliases: ["Bench Press", "플랫 벤치"],
                        inputType: .setsRepsWeight,
                        category: .strength
                    ),
                    makeExercise(
                        id: "barbell-squat",
                        name: "Barbell Squat",
                        localizedName: "바벨 스쿼트",
                        aliases: ["Squat", "스쿼트"],
                        inputType: .setsRepsWeight,
                        category: .strength
                    ),
                    makeExercise(
                        id: "running",
                        name: "Running",
                        localizedName: "러닝",
                        aliases: ["Running", "러닝"],
                        inputType: .durationDistance,
                        category: .cardio,
                        cardioSecondaryUnit: .km
                    ),
                ]
            )
        )
    }

    private func makeExercise(
        id: String,
        name: String,
        localizedName: String,
        aliases: [String],
        inputType: ExerciseInputType,
        category: ExerciseCategory,
        cardioSecondaryUnit: CardioSecondaryUnit? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: localizedName,
            category: category,
            inputType: inputType,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            equipment: .barbell,
            metValue: 5.5,
            aliases: aliases,
            cardioSecondaryUnit: cardioSecondaryUnit
        )
    }
}
