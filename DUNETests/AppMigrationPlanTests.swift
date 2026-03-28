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
