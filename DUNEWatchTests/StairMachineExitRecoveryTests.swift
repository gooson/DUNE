import Foundation
import HealthKit
import Testing
@testable import DUNEWatch

@Suite("Stair exit reminder recovery", .serialized)
@MainActor
struct StairMachineExitRecoveryTests {
    private let recoveryKey = "com.raftel.dailve.workoutRecovery"

    @Test("Keep Running is saved immediately and restored with the same workout")
    func dismissalSurvivesRecovery() async throws {
        let previousData = UserDefaults.standard.data(forKey: recoveryKey)
        let manager = WorkoutManager.shared
        manager.reset()
        defer {
            manager.reset()
            if let previousData { UserDefaults.standard.set(previousData, forKey: recoveryKey) }
        }

        try await manager.startCardioSession(activityType: .stairClimbing, isOutdoor: false)
        manager.keepStairWorkoutRunning()
        let saved = try #require(UserDefaults.standard.data(forKey: recoveryKey))
        let snapshot = try JSONDecoder().decode(RecoverySnapshot.self, from: saved)
        #expect(snapshot.hasDismissedStairExitPrompt == true)

        manager.reset()
        UserDefaults.standard.set(saved, forKey: recoveryKey)
        manager.restoreRecoveredSessionState(.running, at: Date())
        #expect(manager.hasDismissedStairExitPrompt)
    }

    @Test("Recovery snapshots without a dismissal field remain compatible")
    func legacySnapshot() async throws {
        let previousData = UserDefaults.standard.data(forKey: recoveryKey)
        let manager = WorkoutManager.shared
        manager.reset()
        defer {
            manager.reset()
            if let previousData { UserDefaults.standard.set(previousData, forKey: recoveryKey) }
        }

        try await manager.startCardioSession(activityType: .stairClimbing, isOutdoor: false)
        let saved = try #require(UserDefaults.standard.data(forKey: recoveryKey))
        var legacy = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        legacy.removeValue(forKey: "hasDismissedStairExitPrompt")
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        manager.keepStairWorkoutRunning()
        UserDefaults.standard.set(legacyData, forKey: recoveryKey)

        manager.restoreRecoveredSessionState(.running, at: Date())
        #expect(!manager.hasDismissedStairExitPrompt)
        #expect(manager.workoutMode == .cardio(activityType: .stairClimbing, isOutdoor: false))
    }

    @Test("A new workout clears the previous workout's dismissal")
    func newWorkout() async throws {
        let previousData = UserDefaults.standard.data(forKey: recoveryKey)
        let manager = WorkoutManager.shared
        manager.reset()
        defer {
            manager.reset()
            if let previousData { UserDefaults.standard.set(previousData, forKey: recoveryKey) }
        }

        try await manager.startCardioSession(activityType: .stairClimbing, isOutdoor: false)
        manager.keepStairWorkoutRunning()
        manager.end()
        try await manager.startCardioSession(activityType: .stairClimbing, isOutdoor: false)

        #expect(!manager.hasDismissedStairExitPrompt)
        let saved = try #require(UserDefaults.standard.data(forKey: recoveryKey))
        let snapshot = try JSONDecoder().decode(RecoverySnapshot.self, from: saved)
        #expect(snapshot.hasDismissedStairExitPrompt == false)
    }

    private struct RecoverySnapshot: Decodable {
        let hasDismissedStairExitPrompt: Bool?
    }
}
