import Foundation
import SwiftData

/// Stores per-exercise default values (weight, reps) synced via CloudKit.
/// Priority: manual override > auto-remembered (last used) > global default.
@Model
final class ExerciseDefaultRecord {
    var id: UUID = UUID()
    /// Matches ExerciseDefinition.id
    var exerciseDefinitionID: String = ""
    /// Default weight in kg (nil = use global default)
    var defaultWeight: Double?
    /// Default reps (nil = no default)
    var defaultReps: Int?
    /// true when user explicitly set the value in Settings
    var isManualOverride: Bool = false
    /// Last time this exercise was used (for sorting in Settings list)
    var lastUsedDate: Date = Date()

    init(
        exerciseDefinitionID: String,
        defaultWeight: Double? = nil,
        defaultReps: Int? = nil,
        isManualOverride: Bool = false,
        lastUsedDate: Date = Date()
    ) {
        self.id = UUID()
        self.exerciseDefinitionID = exerciseDefinitionID
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps
        self.isManualOverride = isManualOverride
        self.lastUsedDate = lastUsedDate
    }
}
