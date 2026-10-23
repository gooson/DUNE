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
            let machineLevelEventCount: Int?
        }
        let data = try #require(UserDefaults.standard.data(forKey: "com.raftel.dailve.workoutRecovery"))
        let historyData = try Data(contentsOf: WorkoutManager.recoveryHistoryURL)
        let recovered = try JSONDecoder().decode(RecoverySnapshot.self, from: data)
        #expect(recovered.machineLevelChanges == nil)
        #expect(recovered.machineLevelEventCount == 3)
        #expect(historyData.split(separator: 0x0A).count == 3)

        // Recreate the manager's transient state, then restore the saved paused workout.
        manager.reset()
        try await manager.startCardioSession(
            activityType: .stairClimbing,
            isOutdoor: false,
            secondaryUnit: .floors,
            initialLevel: 1
        )
        UserDefaults.standard.set(data, forKey: "com.raftel.dailve.workoutRecovery")
        try historyData.write(to: WorkoutManager.recoveryHistoryURL, options: .atomic)
        manager.restoreRecoveredSessionState(.paused, at: Date())
        #expect(manager.isPaused)
        #expect(manager.machineLevelChanges.map(\.level) == [5, 7, 8])

        try? await Task.sleep(for: .milliseconds(100))
        let handle = try FileHandle(forWritingTo: WorkoutManager.recoveryHistoryURL)
        _ = try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"incomplete\"".utf8))
        try handle.close()
        manager.setMachineLevel(9)
        let recoveredTime = try #require(manager.machineLevelChanges.last?.elapsedSeconds)
        #expect(abs(recoveredTime - pausedTime) < 0.2)
        #expect(manager.machineLevelChanges.map(\.level) == [5, 7, 8, 9])
        let compactState = try #require(UserDefaults.standard.data(forKey: "com.raftel.dailve.workoutRecovery"))
        #expect(compactState.count < 64_000)
        #expect(try JSONDecoder().decode(RecoverySnapshot.self, from: compactState).machineLevelEventCount == 4)
        let historyLines = try Data(contentsOf: WorkoutManager.recoveryHistoryURL).split(separator: 0x0A)
        #expect(historyLines.count == 4)
        #expect(historyLines.allSatisfy { (try? JSONSerialization.jsonObject(with: Data($0))) != nil })

        // If the last disk append fails, the newer snapshot still owns the current level.
        manager.reset()
        try await manager.startCardioSession(
            activityType: .stairClimbing,
            isOutdoor: false,
            secondaryUnit: .floors,
            initialLevel: 1
        )
        UserDefaults.standard.set(compactState, forKey: "com.raftel.dailve.workoutRecovery")
        try historyData.write(to: WorkoutManager.recoveryHistoryURL, options: .atomic)
        manager.restoreRecoveredSessionState(.paused, at: Date())
        #expect(manager.currentMachineLevel == 9)
    }
}
