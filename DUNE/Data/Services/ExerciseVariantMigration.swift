import Foundation
import SwiftData
import os

/// One-time migration that rewrites legacy variant exercise IDs in persisted records
/// to their canonical base exercise IDs after the exercise library consolidation.
///
/// Safe to call on every launch — skips records that already reference valid base IDs.
enum ExerciseVariantMigration {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "DUNE",
        category: "ExerciseVariantMigration"
    )

    private static let migrationKey = "ExerciseVariantMigration.completed.v1"

    /// Migrates ExerciseRecord, ExerciseDefaultRecord, and WorkoutTemplate entries
    /// that reference removed variant IDs to their canonical base IDs.
    @MainActor
    static func migrateIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let library = ExerciseLibraryService.shared
        var totalMigrated = 0

        // 1. ExerciseRecord
        totalMigrated += migrateExerciseRecords(in: context, library: library)

        // 2. ExerciseDefaultRecord
        totalMigrated += migrateExerciseDefaults(in: context, library: library)

        // 3. WorkoutTemplate
        totalMigrated += migrateWorkoutTemplates(in: context, library: library)

        UserDefaults.standard.set(true, forKey: migrationKey)

        if totalMigrated > 0 {
            logger.info("Migrated \(totalMigrated, privacy: .public) records from variant to base exercise IDs")
        }
    }

    // MARK: - ExerciseRecord

    @MainActor
    private static func migrateExerciseRecords(
        in context: ModelContext,
        library: ExerciseLibraryService
    ) -> Int {
        let descriptor = FetchDescriptor<ExerciseRecord>()
        guard let records = try? context.fetch(descriptor) else { return 0 }

        var count = 0
        for record in records {
            guard let defID = record.exerciseDefinitionID, !defID.isEmpty else { continue }

            let resolved = ExerciseLibraryService.resolvedExerciseID(for: defID)
            guard resolved != defID else { continue }

            if let base = library.exercise(byID: resolved) {
                record.exerciseDefinitionID = resolved
                record.exerciseType = base.localizedName
                count += 1
            }
        }
        return count
    }

    // MARK: - ExerciseDefaultRecord

    @MainActor
    private static func migrateExerciseDefaults(
        in context: ModelContext,
        library: ExerciseLibraryService
    ) -> Int {
        let descriptor = FetchDescriptor<ExerciseDefaultRecord>()
        guard let records = try? context.fetch(descriptor) else { return 0 }

        var count = 0
        for record in records {
            let defID = record.exerciseDefinitionID
            guard !defID.isEmpty else { continue }

            let resolved = ExerciseLibraryService.resolvedExerciseID(for: defID)
            guard resolved != defID else { continue }

            record.exerciseDefinitionID = resolved
            count += 1
        }
        return count
    }

    // MARK: - WorkoutTemplate

    @MainActor
    private static func migrateWorkoutTemplates(
        in context: ModelContext,
        library: ExerciseLibraryService
    ) -> Int {
        let descriptor = FetchDescriptor<WorkoutTemplate>()
        guard let templates = try? context.fetch(descriptor) else { return 0 }

        var count = 0
        for template in templates {
            var needsUpdate = false
            var updatedEntries: [TemplateEntry] = []

            for entry in template.exerciseEntries {
                let defID = entry.exerciseDefinitionID
                let resolved = ExerciseLibraryService.resolvedExerciseID(for: defID)

                if resolved != defID, let base = library.exercise(byID: resolved) {
                    let migrated = TemplateEntry(
                        exerciseDefinitionID: resolved,
                        exerciseName: base.localizedName,
                        defaultSets: entry.defaultSets,
                        defaultReps: entry.defaultReps,
                        defaultWeightKg: entry.defaultWeightKg,
                        restDuration: entry.restDuration,
                        equipment: entry.equipment,
                        inputTypeRaw: entry.inputTypeRaw,
                        cardioSecondaryUnitRaw: entry.cardioSecondaryUnitRaw
                    )
                    updatedEntries.append(migrated)
                    needsUpdate = true
                } else {
                    updatedEntries.append(entry)
                }
            }

            if needsUpdate {
                template.exerciseEntries = updatedEntries
                template.updatedAt = Date()
                count += 1
            }
        }
        return count
    }
}
