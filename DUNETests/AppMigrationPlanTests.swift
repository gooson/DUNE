import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("AppMigrationPlan")
struct AppMigrationPlanTests {
    @Test("Current schema stays aligned with latest migration version")
    func currentSchemaMatchesLatestVersionedSchema() {
        let latestModelNames = Set(AppSchemaV16.models.map { String(describing: $0) })
        let currentModelNames = Set(AppMigrationPlan.currentSchema.entities.map(\.name))

        #expect(currentModelNames == latestModelNames)
        #expect(currentModelNames.contains("InjuryRecord"))
        #expect(currentModelNames.contains("HabitDefinition"))
        #expect(currentModelNames.contains("HabitLog"))
        #expect(currentModelNames.contains("ExerciseDefaultRecord"))
        #expect(currentModelNames.contains("HealthSnapshotMirrorRecord"))
        #expect(currentModelNames.contains("HourlyScoreSnapshot"))
        #expect(currentModelNames.contains("PostureAssessmentRecord"))
    }

    @Test("V12 and V13 freeze ExerciseDefaultRecord snapshots while V14+ adopt the live model")
    func exerciseDefaultSnapshotsStayDistinctFromLiveModel() {
        let v12ModelIDs = Set(AppSchemaV12.models.map(ObjectIdentifier.init))
        let v13ModelIDs = Set(AppSchemaV13.models.map(ObjectIdentifier.init))
        let v14ModelIDs = Set(AppSchemaV14.models.map(ObjectIdentifier.init))
        let v15ModelIDs = Set(AppSchemaV15.models.map(ObjectIdentifier.init))
        let v16ModelIDs = Set(AppSchemaV16.models.map(ObjectIdentifier.init))

        #expect(v12ModelIDs.contains(ObjectIdentifier(AppSchemaV12.ExerciseDefaultRecord.self)))
        #expect(!v12ModelIDs.contains(ObjectIdentifier(ExerciseDefaultRecord.self)))
        #expect(v13ModelIDs.contains(ObjectIdentifier(AppSchemaV13.ExerciseDefaultRecord.self)))
        #expect(!v13ModelIDs.contains(ObjectIdentifier(ExerciseDefaultRecord.self)))
        #expect(v14ModelIDs.contains(ObjectIdentifier(ExerciseDefaultRecord.self)))
        #expect(v15ModelIDs.contains(ObjectIdentifier(ExerciseDefaultRecord.self)))
        #expect(v16ModelIDs.contains(ObjectIdentifier(ExerciseDefaultRecord.self)))
    }

    @Test("V12 and V13 freeze ExerciseRecord and WorkoutSet together before V14+ adopt live models")
    func relationshipSnapshotsStayDistinctFromLiveModels() {
        let v12ModelIDs = Set(AppSchemaV12.models.map(ObjectIdentifier.init))
        let v13ModelIDs = Set(AppSchemaV13.models.map(ObjectIdentifier.init))
        let v14ModelIDs = Set(AppSchemaV14.models.map(ObjectIdentifier.init))
        let v15ModelIDs = Set(AppSchemaV15.models.map(ObjectIdentifier.init))
        let v16ModelIDs = Set(AppSchemaV16.models.map(ObjectIdentifier.init))

        #expect(v12ModelIDs.contains(ObjectIdentifier(AppSchemaV12.V12ExerciseRecord.self)))
        #expect(v13ModelIDs.contains(ObjectIdentifier(AppSchemaV13.V13ExerciseRecord.self)))
        #expect(!v12ModelIDs.contains(ObjectIdentifier(ExerciseRecord.self)))
        #expect(!v13ModelIDs.contains(ObjectIdentifier(ExerciseRecord.self)))
        #expect(v14ModelIDs.contains(ObjectIdentifier(ExerciseRecord.self)))
        #expect(v15ModelIDs.contains(ObjectIdentifier(ExerciseRecord.self)))
        #expect(v16ModelIDs.contains(ObjectIdentifier(ExerciseRecord.self)))

        #expect(v12ModelIDs.contains(ObjectIdentifier(AppSchemaV12.V12WorkoutSet.self)))
        #expect(v13ModelIDs.contains(ObjectIdentifier(AppSchemaV13.V13WorkoutSet.self)))
        #expect(!v12ModelIDs.contains(ObjectIdentifier(WorkoutSet.self)))
        #expect(!v13ModelIDs.contains(ObjectIdentifier(WorkoutSet.self)))
        #expect(v14ModelIDs.contains(ObjectIdentifier(WorkoutSet.self)))
        #expect(v15ModelIDs.contains(ObjectIdentifier(WorkoutSet.self)))
        #expect(v16ModelIDs.contains(ObjectIdentifier(WorkoutSet.self)))
    }

    @Test("V15 adds HourlyScoreSnapshot to the live current schema")
    func hourlyScoreSnapshotBelongsToLatestSchema() {
        let v15ModelIDs = Set(AppSchemaV15.models.map(ObjectIdentifier.init))

        #expect(v15ModelIDs.contains(ObjectIdentifier(HourlyScoreSnapshot.self)))
    }

    @Test("V16 adds PostureAssessmentRecord to the live current schema")
    func postureAssessmentRecordBelongsToLatestSchema() {
        let v16ModelIDs = Set(AppSchemaV16.models.map(ObjectIdentifier.init))

        #expect(v16ModelIDs.contains(ObjectIdentifier(PostureAssessmentRecord.self)))
    }

    @Test("Migration plan builds an in-memory model container without duplicate checksums")
    func migrationPlanBuildsContainer() throws {
        _ = try ModelContainer(
            for: AppMigrationPlan.currentSchema,
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Migration plan reopens a V11 on-disk store")
    func migrationPlanReopensV11Store() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }

        try createStore(at: storeURL, schema: Schema(AppSchemaV11.models))
        _ = try reopenStoreWithMigrationPlan(at: storeURL)
    }

    @Test("Migration plan reopens a V12 on-disk store")
    func migrationPlanReopensV12Store() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }

        try createStore(at: storeURL, schema: Schema(AppSchemaV12.models))
        _ = try reopenStoreWithMigrationPlan(at: storeURL)
    }

    @Test("Migration plan reopens a V13 on-disk store")
    func migrationPlanReopensV13Store() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }

        try createStore(at: storeURL, schema: Schema(AppSchemaV13.models))
        _ = try reopenStoreWithMigrationPlan(at: storeURL)
    }

    @Test("Migration plan reopens a V14 on-disk store")
    func migrationPlanReopensV14Store() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }

        try createStore(at: storeURL, schema: Schema(AppSchemaV14.models))
        _ = try reopenStoreWithMigrationPlan(at: storeURL)
    }

    @Test("Migration plan reopens a V15 on-disk store")
    func migrationPlanReopensV15Store() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }

        try createStore(at: storeURL, schema: Schema(AppSchemaV15.models))
        _ = try reopenStoreWithMigrationPlan(at: storeURL)
    }

    private func createStore(at url: URL, schema: Schema) throws {
        _ = try ModelContainer(
            for: schema,
            configurations: persistentConfiguration(for: schema, url: url)
        )
    }

    private func reopenStoreWithMigrationPlan(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: AppMigrationPlan.currentSchema,
            migrationPlan: AppMigrationPlan.self,
            configurations: persistentConfiguration(for: AppMigrationPlan.currentSchema, url: url)
        )
    }

    private func persistentConfiguration(for schema: Schema, url: URL) -> ModelConfiguration {
        ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
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
