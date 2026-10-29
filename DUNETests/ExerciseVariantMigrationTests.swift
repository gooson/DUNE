import Foundation
import Testing
@testable import DUNE

@Suite("ExerciseVariantMigration")
@MainActor
struct ExerciseVariantMigrationTests {
    private let migrationKey = "ExerciseVariantMigration.completed.v1"

    private enum SimulatedFailure: Error {
        case fetch
        case save
    }

    @Test("Failed fetch leaves completion unset and can be retried", arguments: [0, 1, 2])
    func fetchFailureCanRetry(failingFetch: Int) throws {
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let record = ExerciseRecord(
            exerciseType: "Running Intervals",
            exerciseDefinitionID: "running-intervals"
        )
        var shouldFail = true
        var saveCount = 0
        let store = ExerciseVariantMigration.Store(
            fetchRecords: {
                if shouldFail && failingFetch == 0 { throw SimulatedFailure.fetch }
                return [record]
            },
            fetchDefaults: {
                if shouldFail && failingFetch == 1 { throw SimulatedFailure.fetch }
                return []
            },
            fetchTemplates: {
                if shouldFail && failingFetch == 2 { throw SimulatedFailure.fetch }
                return []
            },
            save: { saveCount += 1 }
        )

        ExerciseVariantMigration.migrateIfNeeded(store: store, defaults: defaults)
        #expect(!defaults.bool(forKey: migrationKey))
        #expect(record.exerciseDefinitionID == "running-intervals")
        #expect(saveCount == 0)

        shouldFail = false
        ExerciseVariantMigration.migrateIfNeeded(store: store, defaults: defaults)
        #expect(defaults.bool(forKey: migrationKey))
        #expect(record.exerciseDefinitionID == "running")
        #expect(saveCount == 1)
    }

    @Test("Failed save retries even when records were already mutated in memory")
    func saveFailureCanRetryAfterPartialMutation() throws {
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let record = ExerciseRecord(
            exerciseType: "Running Intervals",
            duration: 1800,
            calories: 250,
            exerciseDefinitionID: "running-intervals"
        )
        let exerciseDefault = ExerciseDefaultRecord(
            exerciseDefinitionID: "running-intervals",
            defaultWeight: 25,
            defaultReps: 8,
            isManualOverride: true
        )
        let template = WorkoutTemplate(name: "Intervals", exerciseEntries: [
            TemplateEntry(
                exerciseDefinitionID: "running-intervals",
                exerciseName: "Running Intervals",
                defaultSets: 4,
                defaultReps: 6,
                defaultWeightKg: 30,
                restDuration: 90,
                equipment: "bodyweight",
                inputTypeRaw: "durationDistance",
                cardioSecondaryUnitRaw: "km"
            )
        ])
        let recordID = record.id
        let defaultID = exerciseDefault.id
        let templateEntryID = template.exerciseEntries[0].id
        var shouldFailSave = true
        var saveCount = 0
        let store = ExerciseVariantMigration.Store(
            fetchRecords: { [record] },
            fetchDefaults: { [exerciseDefault] },
            fetchTemplates: { [template] },
            save: {
                saveCount += 1
                if shouldFailSave { throw SimulatedFailure.save }
            }
        )

        ExerciseVariantMigration.migrateIfNeeded(store: store, defaults: defaults)
        #expect(!defaults.bool(forKey: migrationKey))
        #expect(record.exerciseDefinitionID == "running")
        #expect(exerciseDefault.exerciseDefinitionID == "running")
        #expect(template.exerciseEntries.first?.exerciseDefinitionID == "running")
        #expect(saveCount == 1)

        shouldFailSave = false
        ExerciseVariantMigration.migrateIfNeeded(store: store, defaults: defaults)
        #expect(defaults.bool(forKey: migrationKey))
        #expect(saveCount == 2)
        #expect(record.duration == 1800)
        #expect(record.calories == 250)
        #expect(record.id == recordID)
        #expect(exerciseDefault.id == defaultID)
        #expect(template.exerciseEntries.first?.id == templateEntryID)
        #expect(exerciseDefault.defaultWeight == 25)
        #expect(exerciseDefault.defaultReps == 8)
        #expect(exerciseDefault.isManualOverride)
        #expect(template.exerciseEntries.first?.defaultSets == 4)
        #expect(template.exerciseEntries.first?.defaultReps == 6)
        #expect(template.exerciseEntries.first?.defaultWeightKg == 30)
        #expect(template.exerciseEntries.first?.restDuration == 90)
        #expect(template.exerciseEntries.first?.equipment == "bodyweight")
        #expect(template.exerciseEntries.first?.inputTypeRaw == "durationDistance")
        #expect(template.exerciseEntries.first?.cardioSecondaryUnitRaw == "km")
    }

    @Test("Defaults migrate only when the canonical exercise exists, preserving custom values and IDs")
    func defaultsRequireExistingCanonicalExercise() throws {
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let lastUsedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let known = ExerciseDefaultRecord(
            exerciseDefinitionID: "running-intervals",
            defaultWeight: 25,
            defaultReps: 8,
            isManualOverride: true,
            isPreferred: true,
            lastUsedDate: lastUsedDate
        )
        let custom = ExerciseDefaultRecord(
            exerciseDefinitionID: "personal-movement-intervals",
            defaultWeight: 15,
            defaultReps: 12,
            isManualOverride: true,
            isPreferred: true,
            lastUsedDate: lastUsedDate
        )
        let knownID = known.id
        let customID = custom.id
        var saveCount = 0
        let store = ExerciseVariantMigration.Store(
            fetchRecords: { [] },
            fetchDefaults: { [known, custom] },
            fetchTemplates: { [] },
            save: { saveCount += 1 }
        )

        #expect(ExerciseLibraryService.resolvedExerciseID(for: custom.exerciseDefinitionID) == "personal-movement")
        #expect(ExerciseLibraryService.shared.exercise(byID: "running") != nil)
        #expect(ExerciseLibraryService.shared.exercise(byID: "personal-movement") == nil)

        ExerciseVariantMigration.migrateIfNeeded(store: store, defaults: defaults)

        #expect(known.exerciseDefinitionID == "running")
        #expect(custom.exerciseDefinitionID == "personal-movement-intervals")
        #expect(known.id == knownID)
        #expect(custom.id == customID)
        #expect(known.defaultWeight == 25 && custom.defaultWeight == 15)
        #expect(known.defaultReps == 8 && custom.defaultReps == 12)
        #expect(known.isManualOverride && custom.isManualOverride)
        #expect(known.isPreferred && custom.isPreferred)
        #expect(known.lastUsedDate == lastUsedDate && custom.lastUsedDate == lastUsedDate)
        #expect(defaults.bool(forKey: migrationKey))
        #expect(saveCount == 1)
    }

    @Test("Missing library definitions never rewrite default IDs")
    func emptyLibraryPreservesDefaults() throws {
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let record = ExerciseDefaultRecord(exerciseDefinitionID: "running-intervals", defaultReps: 6)
        let store = ExerciseVariantMigration.Store(
            fetchRecords: { [] },
            fetchDefaults: { [record] },
            fetchTemplates: { [] },
            save: { }
        )

        ExerciseVariantMigration.migrateIfNeeded(
            store: store, defaults: defaults, library: ExerciseLibraryService(exercises: [])
        )

        #expect(record.exerciseDefinitionID == "running-intervals")
        #expect(record.defaultReps == 6)
    }

    @Test("No variants still requires a successful save before completion")
    func noVariantsRequiresSave() throws {
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var shouldFailSave = true
        var saveCount = 0
        let store = ExerciseVariantMigration.Store(
            fetchRecords: { [] },
            fetchDefaults: { [] },
            fetchTemplates: { [] },
            save: {
                saveCount += 1
                if shouldFailSave { throw SimulatedFailure.save }
            }
        )

        ExerciseVariantMigration.migrateIfNeeded(store: store, defaults: defaults)
        #expect(!defaults.bool(forKey: migrationKey))

        shouldFailSave = false
        ExerciseVariantMigration.migrateIfNeeded(store: store, defaults: defaults)
        #expect(defaults.bool(forKey: migrationKey))
        #expect(saveCount == 2)
    }

    @Test("Existing completion marker skips fetches and saves")
    func existingCompletionIsPreserved() throws {
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: migrationKey)

        var callCount = 0
        let store = ExerciseVariantMigration.Store(
            fetchRecords: { callCount += 1; return [] },
            fetchDefaults: { callCount += 1; return [] },
            fetchTemplates: { callCount += 1; return [] },
            save: { callCount += 1 }
        )

        ExerciseVariantMigration.migrateIfNeeded(store: store, defaults: defaults)
        #expect(defaults.bool(forKey: migrationKey))
        #expect(callCount == 0)
    }
}
