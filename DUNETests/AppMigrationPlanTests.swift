import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("AppMigrationPlan")
struct AppMigrationPlanTests {
    @Test("Current schema stays aligned with latest migration version")
    func currentSchemaMatchesLatestVersionedSchema() {
        let latestModelNames = Set(AppSchemaV14.models.map { String(describing: $0) })
        let currentModelNames = Set(AppMigrationPlan.currentSchema.entities.map(\.name))

        #expect(currentModelNames == latestModelNames)
        #expect(currentModelNames.contains("InjuryRecord"))
        #expect(currentModelNames.contains("HabitDefinition"))
        #expect(currentModelNames.contains("HabitLog"))
        #expect(currentModelNames.contains("ExerciseDefaultRecord"))
        #expect(currentModelNames.contains("HealthSnapshotMirrorRecord"))
    }

    @Test("V12 freezes ExerciseDefaultRecord before preferred flag and V13 adopts live model")
    func v12SnapshotFreezesExerciseDefaultRecord() {
        let v12ModelIDs = Set(AppSchemaV12.models.map(ObjectIdentifier.init))
        let v13ModelIDs = Set(AppSchemaV13.models.map(ObjectIdentifier.init))

        #expect(v12ModelIDs.contains(ObjectIdentifier(AppSchemaV12.ExerciseDefaultRecord.self)))
        #expect(!v12ModelIDs.contains(ObjectIdentifier(ExerciseDefaultRecord.self)))
        #expect(v13ModelIDs.contains(ObjectIdentifier(ExerciseDefaultRecord.self)))
    }

    @Test("V12 and V13 freeze WorkoutSet before set-level rpe and V14 adopts live model")
    func workoutSetSnapshotsStayDistinctFromLiveModel() {
        let v12ModelIDs = Set(AppSchemaV12.models.map(ObjectIdentifier.init))
        let v13ModelIDs = Set(AppSchemaV13.models.map(ObjectIdentifier.init))
        let v14ModelIDs = Set(AppSchemaV14.models.map(ObjectIdentifier.init))

        #expect(v12ModelIDs.contains(ObjectIdentifier(AppSchemaV12.V12WorkoutSet.self)))
        #expect(v13ModelIDs.contains(ObjectIdentifier(AppSchemaV13.V13WorkoutSet.self)))
        #expect(!v12ModelIDs.contains(ObjectIdentifier(WorkoutSet.self)))
        #expect(!v13ModelIDs.contains(ObjectIdentifier(WorkoutSet.self)))
        #expect(v14ModelIDs.contains(ObjectIdentifier(WorkoutSet.self)))
    }

    @Test("Migration plan builds an in-memory model container without duplicate checksums")
    func migrationPlanBuildsContainer() throws {
        _ = try ModelContainer(
            for: AppMigrationPlan.currentSchema,
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
