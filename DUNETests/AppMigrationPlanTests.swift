import SwiftData
import Testing
@testable import DUNE

@Suite("AppMigrationPlan")
struct AppMigrationPlanTests {
    @Test("full migration chain initializes an in-memory container")
    func fullMigrationChainInitializesContainer() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        _ = try ModelContainer(
            for: ExerciseRecord.self,
            BodyCompositionRecord.self,
            WorkoutSet.self,
            CustomExercise.self,
            WorkoutTemplate.self,
            UserCategory.self,
            InjuryRecord.self,
            ExerciseDefaultRecord.self,
            HabitDefinition.self,
            HabitLog.self,
            HealthSnapshotMirrorRecord.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
    }
}
