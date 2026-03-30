import Foundation
import SwiftData
import os

/// One-time migration that backfills MET-estimated calories for existing
/// Watch strength workout records that were saved with nil calories.
///
/// Safe to call on every launch — skips records that already have calorie data
/// and marks completion via UserDefaults to avoid redundant fetches after first run.
enum CalorieBackfillMigration {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "DUNE",
        category: "CalorieBackfillMigration"
    )

    private static let migrationKey = "CalorieBackfillMigration.completed.v1"

    @MainActor
    static func migrateIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let library = ExerciseLibraryService.shared
        let service = CalorieEstimationService()
        var backfilled = 0

        // Fetch records with no calorie data and manual source (Watch strength pattern).
        let manualRaw = CalorieSource.manual.rawValue
        var descriptor = FetchDescriptor<ExerciseRecord>(
            predicate: #Predicate<ExerciseRecord> {
                $0.calories == nil
                    && $0.estimatedCalories == nil
                    && $0.calorieSourceRaw == manualRaw
            }
        )
        descriptor.fetchLimit = 5000

        guard let records = try? context.fetch(descriptor) else {
            logger.error("Failed to fetch records for calorie backfill")
            return
        }

        for record in records {
            guard let defID = record.exerciseDefinitionID, !defID.isEmpty else { continue }
            guard record.duration > 0 else { continue }
            // Only backfill strength-type exercises (those with set data).
            guard record.hasSetData else { continue }

            guard let definition = library.exercise(byID: defID) else { continue }
            guard definition.metValue > 0 else { continue }

            // Estimate rest time from completed sets.
            let setCount = (record.sets ?? []).filter(\.isCompleted).count
            let estimatedRest = Double(Swift.max(setCount - 1, 0)) * WorkoutSettingsStore.shared.restSeconds

            guard let estimated = service.estimate(
                metValue: definition.metValue,
                bodyWeightKg: CalorieEstimationService.defaultBodyWeightKg,
                durationSeconds: record.duration,
                restSeconds: estimatedRest
            ) else { continue }

            record.estimatedCalories = estimated
            record.calorieSourceRaw = CalorieSource.met.rawValue
            backfilled += 1
        }

        if backfilled > 0 {
            try? context.save()
            logger.info("Backfilled MET calories for \(backfilled, privacy: .public) records")
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
