import Foundation

struct WorkoutTemplateGenerationRequest: Sendable {
    let prompt: String
    let recentRecords: [ExerciseRecordSnapshot]
    let localeIdentifier: String

    init(
        prompt: String,
        recentRecords: [ExerciseRecordSnapshot] = [],
        localeIdentifier: String = Locale.current.identifier
    ) {
        self.prompt = prompt
        self.recentRecords = recentRecords
        self.localeIdentifier = localeIdentifier
    }
}

struct GeneratedWorkoutTemplate: Sendable, Equatable {
    let name: String
    let estimatedMinutes: Int
    let slots: [GeneratedWorkoutExerciseSlot]

    init(
        name: String,
        estimatedMinutes: Int,
        slots: [GeneratedWorkoutExerciseSlot]
    ) {
        self.name = String(name.prefix(100))
        self.estimatedMinutes = min(max(estimatedMinutes, 10), 120)
        self.slots = Array(slots.prefix(8))
    }
}

struct GeneratedWorkoutExerciseSlot: Sendable, Equatable, Identifiable {
    var id: String { exerciseDefinitionID }

    let exerciseDefinitionID: String
    let exerciseName: String
    let sets: Int
    let reps: Int

    init(
        exerciseDefinitionID: String,
        exerciseName: String,
        sets: Int,
        reps: Int
    ) {
        self.exerciseDefinitionID = exerciseDefinitionID
        self.exerciseName = String(exerciseName.prefix(100))
        self.sets = min(max(sets, 1), 10)
        self.reps = min(max(reps, 1), 30)
    }
}
