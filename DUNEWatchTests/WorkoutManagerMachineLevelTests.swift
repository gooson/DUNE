import Foundation
import HealthKit
import Testing
@testable import DUNEWatch

@Suite("Watch machine level history", .serialized)
@MainActor
struct WorkoutManagerMachineLevelTests {
    @Test("Stair climber stores initial and changed levels at active times")
    func stairClimberChanges() async throws {
        let manager = WorkoutManager.shared
        manager.reset()
        defer { manager.reset() }

        try await manager.startCardioSession(
            activityType: .stairClimbing,
            isOutdoor: false,
            secondaryUnit: .floors,
            initialLevel: 5
        )
        manager.adjustMachineLevel(by: 2)
        manager.setMachineLevel(7)
        #expect(manager.machineLevelChanges.map(\.level) == [5, 7])

        manager.pause()
        try? await Task.sleep(for: .milliseconds(100))
        manager.resume()
        manager.pause()
        let pausedTime = manager.activeElapsedTime(at: Date())
        try? await Task.sleep(for: .milliseconds(100))
        manager.setMachineLevel(8)
        #expect(manager.machineLevelChanges.last?.elapsedSeconds == pausedTime)
        #expect(manager.machineLevelChanges.map(\.level) == [5, 7, 8])

        struct RecoverySnapshot: Decodable {
            let machineLevelChanges: [CardioMachineLevelChange]?
        }
        let data = try #require(UserDefaults.standard.data(forKey: "com.raftel.dailve.workoutRecovery"))
        let recovered = try JSONDecoder().decode(RecoverySnapshot.self, from: data)
        #expect(recovered.machineLevelChanges == manager.machineLevelChanges)

        // Recreate the manager's transient state, then restore the saved paused workout.
        manager.reset()
        try await manager.startCardioSession(
            activityType: .stairClimbing,
            isOutdoor: false,
            secondaryUnit: .floors,
            initialLevel: 1
        )
        UserDefaults.standard.set(data, forKey: "com.raftel.dailve.workoutRecovery")
        manager.restoreRecoveredSessionState(.paused, at: Date())
        #expect(manager.isPaused)
        #expect(manager.machineLevelChanges.map(\.level) == [5, 7, 8])

        try? await Task.sleep(for: .milliseconds(100))
        manager.setMachineLevel(9)
        let recoveredTime = try #require(manager.machineLevelChanges.last?.elapsedSeconds)
        #expect(abs(recoveredTime - pausedTime) < 0.2)
        #expect(manager.machineLevelChanges.map(\.level) == [5, 7, 8, 9])
    }
}
