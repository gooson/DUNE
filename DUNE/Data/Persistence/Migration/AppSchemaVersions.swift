import Foundation
import SwiftData

// MARK: - Current Schema (V17)

/// The authoritative list of all @Model types in the current schema.
/// SwiftData performs automatic lightweight migration when the store's
/// schema differs from this list (all historical changes are additive).
///
/// The staged SchemaMigrationPlan that previously lived here was removed
/// because multiple VersionedSchemas referenced live model types whose
/// hashes drifted with each field addition, making the plan unusable
/// (134504 "unknown coordinator model version"). Since every migration
/// from V1 through V17 is purely additive (new models, new optional/
/// defaulted fields), SwiftData's automatic lightweight migration
/// handles all upgrades without an explicit plan.
enum AppSchemaV17: VersionedSchema {
    static let versionIdentifier = Schema.Version(17, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, InjuryRecord.self, HabitDefinition.self, HabitLog.self, UserCategory.self, ExerciseDefaultRecord.self, HealthSnapshotMirrorRecord.self, HourlyScoreSnapshot.self, PostureAssessmentRecord.self]
    }
}

// MARK: - Schema Reference

/// Provides the current schema for ModelContainer initialization.
/// Automatic lightweight migration is used — no explicit SchemaMigrationPlan.
enum AppSchema {
    static let currentSchema = Schema(AppSchemaV17.models)
}
