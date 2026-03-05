import Foundation
import SwiftData

// MARK: - Schema V1 (Original)

enum AppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [V1ExerciseRecord.self, V1BodyCompositionRecord.self]
    }

    @Model
    final class V1ExerciseRecord {
        var id: UUID = UUID()
        var date: Date = Date()
        var exerciseType: String = ""
        var duration: TimeInterval = 0
        var calories: Double?
        var distance: Double?
        var memo: String = ""
        var isFromHealthKit: Bool = false
        var healthKitWorkoutID: String?
        var createdAt: Date = Date()

        init() {}
    }

    @Model
    final class V1BodyCompositionRecord {
        var id: UUID = UUID()
        var date: Date = Date()
        var weight: Double?
        var bodyFatPercentage: Double?
        var muscleMass: Double?
        var memo: String = ""
        var createdAt: Date = Date()

        init() {}
    }
}

// MARK: - Schema V2 (Activity Redesign)

enum AppSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self]
    }
}

// MARK: - Schema V3 (Custom Exercises)

enum AppSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self]
    }
}

// MARK: - Schema V4 (Workout Templates)

enum AppSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self]
    }
}

// MARK: - Schema V5 (Injury Tracking)

enum AppSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, InjuryRecord.self]
    }
}

// MARK: - Schema V6 (Habit Tracking)

enum AppSchemaV6: VersionedSchema {
    static let versionIdentifier = Schema.Version(6, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, InjuryRecord.self, HabitDefinition.self, HabitLog.self]
    }
}

// MARK: - Schema V7 (User Categories & Exercise Defaults)

enum AppSchemaV7: VersionedSchema {
    static let versionIdentifier = Schema.Version(7, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, InjuryRecord.self, HabitDefinition.self, HabitLog.self, UserCategory.self, ExerciseDefaultRecord.self]
    }
}

// MARK: - Schema V8 (Health Snapshot Mirror)

enum AppSchemaV8: VersionedSchema {
    static let versionIdentifier = Schema.Version(8, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, InjuryRecord.self, HabitDefinition.self, HabitLog.self, UserCategory.self, ExerciseDefaultRecord.self, HealthSnapshotMirrorRecord.self]
    }

    @Model
    final class HabitDefinition {
        var id: UUID = UUID()
        var name: String = ""
        var iconCategoryRaw: String = "health"
        var habitTypeRaw: String = "check"
        var goalValue: Double = 1.0
        var goalUnit: String?
        var frequencyTypeRaw: String = "daily"
        var weeklyTargetDays: Int = 3
        var isAutoLinked: Bool = false
        var autoLinkSourceRaw: String?
        var sortOrder: Int = 0
        var isArchived: Bool = false
        var createdAt: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \HabitLog.habitDefinition)
        var logs: [HabitLog]? = []

        init() {}
    }

    @Model
    final class HabitLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var value: Double = 0
        var isAutoCompleted: Bool = false
        var completedAt: Date?
        var memo: String?
        var habitDefinition: HabitDefinition?

        init() {}
    }
}

// MARK: - Schema V9 (Recurring Start Point)

enum AppSchemaV9: VersionedSchema {
    static let versionIdentifier = Schema.Version(9, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            ExerciseRecord.self,
            BodyCompositionRecord.self,
            WorkoutSet.self,
            CustomExercise.self,
            WorkoutTemplate.self,
            InjuryRecord.self,
            HabitDefinition.self,
            HabitLog.self,
            UserCategory.self,
            ExerciseDefaultRecord.self,
            HealthSnapshotMirrorRecord.self,
        ]
    }

    // Snapshot model to preserve pre-VO2Max checksum for V9.
    @Model
    final class ExerciseRecord {
        var id: UUID = UUID()
        var date: Date = Date()
        var exerciseType: String = ""
        var duration: TimeInterval = 0
        var calories: Double?
        var distance: Double?
        var stepCount: Int?
        var averagePaceSecondsPerKm: Double?
        var averageCadenceStepsPerMinute: Double?
        var elevationGainMeters: Double?
        var floorsAscended: Double?
        var memo: String = ""
        var isFromHealthKit: Bool = false
        var healthKitWorkoutID: String?
        var createdAt: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exerciseRecord)
        var sets: [WorkoutSet]? = []
        var exerciseDefinitionID: String?
        var primaryMusclesRaw: [String] = []
        var secondaryMusclesRaw: [String] = []
        var equipmentRaw: String?
        var estimatedCalories: Double?
        var calorieSourceRaw: String = CalorieSource.manual.rawValue
        var rpe: Int?
        var autoIntensityRaw: Double?

        init() {}
    }

    @Model
    final class WorkoutSet {
        var id: UUID = UUID()
        var exerciseRecord: ExerciseRecord?
        var setNumber: Int = 0
        var setTypeRaw: String = SetType.working.rawValue
        var weight: Double?
        var reps: Int?
        var duration: TimeInterval?
        var distance: Double?
        var intensity: Int? = nil
        var isCompleted: Bool = false
        var restDuration: TimeInterval?

        init() {}
    }
}

// MARK: - Schema V10 (Cardio Fitness VO2Max)

enum AppSchemaV10: VersionedSchema {
    static let versionIdentifier = Schema.Version(10, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, InjuryRecord.self, HabitDefinition.self, HabitLog.self, UserCategory.self, ExerciseDefaultRecord.self, HealthSnapshotMirrorRecord.self]
    }
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self, AppSchemaV3.self, AppSchemaV4.self, AppSchemaV5.self, AppSchemaV6.self, AppSchemaV7.self, AppSchemaV8.self, AppSchemaV9.self, AppSchemaV10.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8, migrateV8toV9, migrateV9toV10]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: AppSchemaV2.self,
        toVersion: AppSchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: AppSchemaV3.self,
        toVersion: AppSchemaV4.self
    )

    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: AppSchemaV4.self,
        toVersion: AppSchemaV5.self
    )

    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: AppSchemaV5.self,
        toVersion: AppSchemaV6.self
    )

    static let migrateV6toV7 = MigrationStage.lightweight(
        fromVersion: AppSchemaV6.self,
        toVersion: AppSchemaV7.self
    )

    static let migrateV7toV8 = MigrationStage.lightweight(
        fromVersion: AppSchemaV7.self,
        toVersion: AppSchemaV8.self
    )

    static let migrateV8toV9 = MigrationStage.lightweight(
        fromVersion: AppSchemaV8.self,
        toVersion: AppSchemaV9.self
    )

    static let migrateV9toV10 = MigrationStage.lightweight(
        fromVersion: AppSchemaV9.self,
        toVersion: AppSchemaV10.self
    )
}
