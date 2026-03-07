import Foundation
import Testing
@testable import DUNE

@Suite("AppMigrationPlan")
struct AppMigrationPlanTests {
    @Test("Current schema stays aligned with latest migration version")
    func currentSchemaMatchesLatestVersionedSchema() {
        let latestModelNames = Set(AppSchemaV12.models.map { String(describing: $0) })
        let currentModelNames = Set(AppMigrationPlan.currentSchema.entities.map(\.name))

        #expect(currentModelNames == latestModelNames)
        #expect(currentModelNames.contains("InjuryRecord"))
        #expect(currentModelNames.contains("HabitDefinition"))
        #expect(currentModelNames.contains("HabitLog"))
        #expect(currentModelNames.contains("ExerciseDefaultRecord"))
        #expect(currentModelNames.contains("HealthSnapshotMirrorRecord"))
    }
}
