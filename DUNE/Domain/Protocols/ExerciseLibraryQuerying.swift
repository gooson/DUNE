import Foundation

/// Protocol for querying the exercise library.
/// Defined in Domain layer; implemented by Data layer (ExerciseLibraryService).
protocol ExerciseLibraryQuerying: Sendable {
    func allExercises() -> [ExerciseDefinition]
    func exercise(byID id: String) -> ExerciseDefinition?
    func search(query: String) -> [ExerciseDefinition]
    func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition]
    func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition]
    func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition]
}

extension ExerciseLibraryQuerying {
    /// Resolves template entries to exercise definitions via library lookup + custom fallback.
    func resolveExercises(from entries: [TemplateEntry]) -> [ExerciseDefinition] {
        entries.compactMap { entry in
            if let definition = exercise(byID: entry.exerciseDefinitionID) {
                return definition
            } else if entry.exerciseDefinitionID.hasPrefix("custom-") {
                return ExerciseDefinition(
                    id: entry.exerciseDefinitionID,
                    name: entry.exerciseName,
                    localizedName: entry.exerciseName,
                    category: .strength,
                    inputType: .setsRepsWeight,
                    primaryMuscles: [],
                    secondaryMuscles: [],
                    equipment: .bodyweight,
                    metValue: 5.0
                )
            }
            return nil
        }
    }
}
