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
