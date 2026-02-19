import Foundation

/// A suggested workout with exercises and reasoning
struct WorkoutSuggestion: Sendable {
    let exercises: [SuggestedExercise]
    let reasoning: String
    let focusMuscles: [MuscleGroup]
    /// Active recovery suggestions for rest days (non-empty when exercises is empty)
    let activeRecoverySuggestions: [ActiveRecoverySuggestion]
    /// The muscle that will recover soonest, with estimated ready date
    let nextReadyMuscle: (muscle: MuscleGroup, readyDate: Date)?

    init(
        exercises: [SuggestedExercise],
        reasoning: String,
        focusMuscles: [MuscleGroup],
        activeRecoverySuggestions: [ActiveRecoverySuggestion] = [],
        nextReadyMuscle: (muscle: MuscleGroup, readyDate: Date)? = nil
    ) {
        self.exercises = exercises
        self.reasoning = reasoning
        self.focusMuscles = focusMuscles
        self.activeRecoverySuggestions = activeRecoverySuggestions
        self.nextReadyMuscle = nextReadyMuscle
    }

    var isRestDay: Bool { exercises.isEmpty }
}

struct SuggestedExercise: Identifiable, Sendable {
    let id: String
    let definition: ExerciseDefinition
    let suggestedSets: Int
    let reason: String
    /// Alternative exercises the user can swipe to see
    let alternatives: [ExerciseDefinition]

    init(
        id: String,
        definition: ExerciseDefinition,
        suggestedSets: Int,
        reason: String,
        alternatives: [ExerciseDefinition] = []
    ) {
        self.id = id
        self.definition = definition
        self.suggestedSets = suggestedSets
        self.reason = reason
        self.alternatives = alternatives
    }
}
