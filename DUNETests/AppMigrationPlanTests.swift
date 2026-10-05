import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("AppSchema")
struct AppSchemaTests {
    @Test("Current schema contains all expected model entities")
    func currentSchemaContainsAllModels() {
        let currentModelNames = Set(AppSchema.currentSchema.entities.map(\.name))

        #expect(currentModelNames.contains("ExerciseRecord"))
        #expect(currentModelNames.contains("BodyCompositionRecord"))
        #expect(currentModelNames.contains("WorkoutSet"))
        #expect(currentModelNames.contains("CustomExercise"))
        #expect(currentModelNames.contains("WorkoutTemplate"))
        #expect(currentModelNames.contains("InjuryRecord"))
        #expect(currentModelNames.contains("HabitDefinition"))
        #expect(currentModelNames.contains("HabitLog"))
        #expect(currentModelNames.contains("UserCategory"))
        #expect(currentModelNames.contains("ExerciseDefaultRecord"))
        #expect(currentModelNames.contains("HealthSnapshotMirrorRecord"))
        #expect(currentModelNames.contains("HourlyScoreSnapshot"))
        #expect(currentModelNames.contains("PostureAssessmentRecord"))
        #expect(currentModelNames.count == 13)
    }

    @Test("Schema builds an in-memory model container")
    func schemaBuildsContainer() throws {
        _ = try ModelContainer(
            for: AppSchema.currentSchema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("V17 entity names remain stable in V18")
    func historicalEntityNames() {
        let oldNames = Set(Schema(AppSchemaV17.models).entities.map(\.name))
        let newNames = Set(AppSchema.currentSchema.entities.map(\.name))
        #expect(oldNames == newNames)
        #expect(oldNames.contains("ExerciseRecord"))
        #expect(oldNames.contains("WorkoutSet"))
    }

    @Test("V17 workout migrates and new metadata survives a second reopen")
    func v17WorkoutMigratesAndReopens() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }
        let oldSchema = Schema(AppSchemaV17.models)

        do {
            let configuration = ModelConfiguration(schema: oldSchema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: oldSchema, configurations: configuration)
            let context = ModelContext(container)
            let record = AppSchemaV17.ExerciseRecord(exerciseType: "Squat", duration: 600, rpe: 8)
            let set = AppSchemaV17.WorkoutSet(setNumber: 1, weight: 80, reps: 5, isCompleted: true, rpe: 8.5)
            set.exerciseRecord = record
            record.sets = [set]
            context.insert(record)
            try context.save()
        }

        do {
            let configuration = ModelConfiguration(schema: AppSchema.currentSchema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: AppSchema.currentSchema, configurations: configuration)
            let context = ModelContext(container)
            let records = try context.fetch(FetchDescriptor<ExerciseRecord>())
            #expect(records.count == 1)
            let record = try #require(records.first)
            #expect(record.exerciseType == "Squat")
            #expect(record.duration == 600)
            #expect(record.rpe == 8)
            #expect(record.plannedSetCount == nil)
            #expect(record.effortSourceRaw == nil)
            let set = try #require(record.sets?.first)
            #expect(set.reps == 5)
            #expect(set.weight == 80)
            #expect(set.rpe == 8.5)
            #expect(set.plannedReps == nil)
            #expect(set.rpeSourceRaw == nil)

            record.plannedSetCount = 3
            record.effortSourceRaw = "user"
            set.plannedReps = 6
            set.rpeSourceRaw = "user"
            try context.save()
        }

        let configuration = ModelConfiguration(schema: AppSchema.currentSchema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: AppSchema.currentSchema, configurations: configuration)
        let context = ModelContext(container)
        let record = try #require(context.fetch(FetchDescriptor<ExerciseRecord>()).first)
        #expect(record.plannedSetCount == 3)
        #expect(record.effortSourceRaw == "user")
        let set = try #require(record.sets?.first)
        #expect(set.reps == 5)
        #expect(set.plannedReps == 6)
        #expect(set.rpeSourceRaw == "user")
    }

    @Test("Automatic migration reopens a persisted store")
    func automaticMigrationReopensStore() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }

        // Create a store with the current schema.
        let config = ModelConfiguration(
            schema: AppSchema.currentSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: AppSchema.currentSchema, configurations: config)

        // Insert a record to verify the store is functional.
        let context = ModelContext(container)
        let record = BodyCompositionRecord(date: Date(), weight: 70)
        context.insert(record)
        try context.save()

        // Reopen — automatic lightweight migration should succeed.
        let reopenConfig = ModelConfiguration(
            schema: AppSchema.currentSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let reopened = try ModelContainer(for: AppSchema.currentSchema, configurations: reopenConfig)
        let reopenedContext = ModelContext(reopened)
        let fetched = try reopenedContext.fetch(FetchDescriptor<BodyCompositionRecord>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.weight == 70)
    }

    private func makeTemporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
    }

    private func removeStoreFiles(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
