import Foundation
import SwiftData

/// A reusable workout template containing a sequence of exercises with default parameters.
@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var exerciseEntries: [TemplateEntry] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String, exerciseEntries: [TemplateEntry] = []) {
        self.id = UUID()
        self.name = String(name.prefix(100))
        self.exerciseEntries = exerciseEntries
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// A single exercise entry within a workout template.
/// Uses Codable so it can be stored as a transformable array in SwiftData.
struct TemplateEntry: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    let exerciseDefinitionID: String
    let exerciseName: String
    var defaultSets: Int
    var defaultReps: Int
    var defaultWeightKg: Double?
    /// Rest duration in seconds between sets for this exercise (nil = use global default 60s)
    var restDuration: TimeInterval?

    init(
        exerciseDefinitionID: String,
        exerciseName: String,
        defaultSets: Int = 3,
        defaultReps: Int = 10,
        defaultWeightKg: Double? = nil,
        restDuration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.exerciseDefinitionID = exerciseDefinitionID
        self.exerciseName = String(exerciseName.prefix(100))
        self.defaultSets = min(max(defaultSets, 1), 20)
        self.defaultReps = min(max(defaultReps, 1), 100)
        if let weight = defaultWeightKg {
            self.defaultWeightKg = min(max(weight, 0), 500)
        } else {
            self.defaultWeightKg = nil
        }
        if let rest = restDuration {
            self.restDuration = min(max(rest, 0), 600) // Max 10 minutes
        } else {
            self.restDuration = nil
        }
    }
}
