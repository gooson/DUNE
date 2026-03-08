import Foundation

protocol NaturalLanguageWorkoutGenerating: Sendable {
    var isAvailable: Bool { get }

    func generateTemplate(
        from request: WorkoutTemplateGenerationRequest,
        library: ExerciseLibraryQuerying
    ) async throws -> GeneratedWorkoutTemplate
}

enum WorkoutTemplateGenerationError: Error, Sendable, Equatable {
    case unavailable
    case emptyPrompt
    case noExercisesMatched
    case invalidTemplate
    case generationFailed
}
