import Foundation

/// Status of each exercise within a sequential template workout
enum TemplateExerciseStatus: Sendable {
    case pending
    case inProgress
    case completed
    case skipped
}

/// Configuration for a sequential template workout session.
/// Each exercise is recorded individually and saved immediately upon completion.
struct TemplateWorkoutConfig: Sendable, Identifiable, Hashable {
    let id = UUID()
    let templateName: String
    let exercises: [ExerciseDefinition]
    let templateEntries: [TemplateEntry]

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
