import Foundation
import SwiftData
import os

/// One-time migration that rewrites legacy variant exercise IDs in persisted records
/// to their canonical base exercise IDs after the exercise library consolidation.
///
/// Safe to call on every launch — skips records that already reference valid base IDs.
enum ExerciseVariantMigration {
    @MainActor
    struct Store {
        let fetchRecords: @MainActor () throws -> [ExerciseRecord]
        let fetchDefaults: @MainActor () throws -> [ExerciseDefaultRecord]
        let fetchTemplates: @MainActor () throws -> [WorkoutTemplate]
        let save: @MainActor () throws -> Void

        init(context: ModelContext) {
            fetchRecords = { try context.fetch(FetchDescriptor<ExerciseRecord>()) }
            fetchDefaults = { try context.fetch(FetchDescriptor<ExerciseDefaultRecord>()) }
            fetchTemplates = { try context.fetch(FetchDescriptor<WorkoutTemplate>()) }
            save = { try context.save() }
        }

        init(
            fetchRecords: @escaping @MainActor () throws -> [ExerciseRecord],
            fetchDefaults: @escaping @MainActor () throws -> [ExerciseDefaultRecord],
            fetchTemplates: @escaping @MainActor () throws -> [WorkoutTemplate],
            save: @escaping @MainActor () throws -> Void
        ) {
            self.fetchRecords = fetchRecords
            self.fetchDefaults = fetchDefaults
            self.fetchTemplates = fetchTemplates
            self.save = save
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "DUNE",
        category: "ExerciseVariantMigration"
    )

    private static let migrationKey = "ExerciseVariantMigration.completed.v1"

    /// Migrates ExerciseRecord, ExerciseDefaultRecord, and WorkoutTemplate entries
    /// that reference removed variant IDs to their canonical base IDs.
    @MainActor
    static func migrateIfNeeded(in context: ModelContext) {
        migrateIfNeeded(store: Store(context: context), defaults: .standard)
    }

    @MainActor
    static func migrateIfNeeded(
        store: Store,
        defaults: UserDefaults,
        library: ExerciseLibraryService = .shared
    ) {
        guard !defaults.bool(forKey: migrationKey) else { return }

        let records: [ExerciseRecord]
        let exerciseDefaults: [ExerciseDefaultRecord]
        let templates: [WorkoutTemplate]
        do {
            // Fetch all stores before mutating any records.
            records = try store.fetchRecords()
            exerciseDefaults = try store.fetchDefaults()
            templates = try store.fetchTemplates()
        } catch {
            logger.error("Exercise variant migration fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        let totalMigrated = migrateExerciseRecords(records, library: library)
            + migrateExerciseDefaults(exerciseDefaults, library: library)
            + migrateWorkoutTemplates(templates, library: library)

        do {
            // Save even when no IDs changed: a prior failed save may have left
            // already-mutated records in this context.
            try store.save()
        } catch {
            logger.error("Exercise variant migration save failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        defaults.set(true, forKey: migrationKey)
        logger.info("Migrated \(totalMigrated, privacy: .public) records from variant to base exercise IDs")
    }

    // MARK: - ExerciseRecord

    @MainActor
    private static func migrateExerciseRecords(
        _ records: [ExerciseRecord],
        library: ExerciseLibraryService
    ) -> Int {
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
        _ records: [ExerciseDefaultRecord],
        library: ExerciseLibraryService
    ) -> Int {
        var count = 0
        for record in records {
            let defID = record.exerciseDefinitionID
            guard !defID.isEmpty else { continue }

            let resolved = ExerciseLibraryService.resolvedExerciseID(for: defID)
            guard resolved != defID, library.exercise(byID: resolved) != nil else { continue }

            record.exerciseDefinitionID = resolved
            count += 1
        }
        return count
    }

    // MARK: - WorkoutTemplate

    @MainActor
    private static func migrateWorkoutTemplates(
        _ templates: [WorkoutTemplate],
        library: ExerciseLibraryService
    ) -> Int {
        var count = 0
        for template in templates {
            var needsUpdate = false
            var updatedEntries: [TemplateEntry] = []

            for entry in template.exerciseEntries {
                let defID = entry.exerciseDefinitionID
                let resolved = ExerciseLibraryService.resolvedExerciseID(for: defID)

                if resolved != defID, let base = library.exercise(byID: resolved) {
                    var migrated = TemplateEntry(
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
                    migrated.id = entry.id
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
