import Foundation
import Testing
@testable import DUNEWatch

@Suite("Watch confirmed RPE recovery", .serialized)
@MainActor
struct WorkoutManagerRPERecoveryTests {
    @Test("Confirming effort updates recovery before another set is completed")
    func confirmedRPEIsPersistedImmediately() async throws {
        let key = "com.raftel.dailve.workoutRecovery"
        let previousData = UserDefaults.standard.data(forKey: key)
        let manager = WorkoutManager.shared
        manager.reset()
        defer {
            manager.reset()
            if let previousData { UserDefaults.standard.set(previousData, forKey: key) }
        }
        let entry = TemplateEntry(
            exerciseDefinitionID: "rpe-recovery-test", exerciseName: "Squat",
            defaultSets: 3, defaultReps: 8, defaultWeightKg: 40
        )
        try await manager.startQuickWorkout(with: WorkoutSessionTemplate(name: "Recovery", entries: [entry]))
        manager.completeSet(weight: 40, reps: 8)
        manager.recordSetRPE(9, source: "user")

        struct RecoverySnapshot: Decodable {
            let completedSets: [[CompletedSetData]]
        }
        let data = try #require(UserDefaults.standard.data(forKey: key))
        let state = try JSONDecoder().decode(RecoverySnapshot.self, from: data)
        let set = try #require(state.completedSets.first?.first)
        #expect(set.rpe == 9)
        #expect(set.rpeSourceRaw == "user")
        #expect(set.plannedReps == 8)
        #expect(manager.currentSetIndex == 0)
    }
}
