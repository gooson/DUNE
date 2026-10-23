import Foundation
import Testing
@testable import DUNE

@Suite("WatchWorkoutSnapshot")
struct WatchWorkoutSnapshotTests {
    private let startedAt = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(
        phase: WatchWorkoutSnapshot.Phase = .running,
        updatedAt: Date? = nil,
        elapsedSeconds: TimeInterval = 125,
        heartRate: Double? = 142,
        activeCalories: Double = 24.5,
        distanceMeters: Double = 1_250,
        exerciseName: String = "Outdoor Run"
    ) -> WatchWorkoutSnapshot {
        WatchWorkoutSnapshot(
            startedAt: startedAt,
            updatedAt: updatedAt ?? startedAt.addingTimeInterval(300),
            exerciseName: exerciseName,
            elapsedSeconds: elapsedSeconds,
            phase: phase,
            heartRate: heartRate,
            activeCalories: activeCalories,
            distanceMeters: distanceMeters
        )
    }

    @Test("Round trips through JSON")
    func jsonRoundTrip() throws {
        let original = snapshot()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchWorkoutSnapshot.self, from: data)

        #expect(decoded == original)
        #expect(decoded.isValid)
    }

    @Test("Rejects non-finite and out-of-range numeric values")
    func rejectsInvalidNumbers() {
        var invalidSnapshots: [WatchWorkoutSnapshot] = []

        invalidSnapshots.append(snapshot(elapsedSeconds: .nan))
        invalidSnapshots.append(snapshot(elapsedSeconds: .infinity))
        invalidSnapshots.append(snapshot(elapsedSeconds: -.infinity))
        invalidSnapshots.append(snapshot(elapsedSeconds: -1))
        invalidSnapshots.append(snapshot(elapsedSeconds: 172_801))
        invalidSnapshots.append(snapshot(heartRate: .nan))
        invalidSnapshots.append(snapshot(heartRate: .infinity))
        invalidSnapshots.append(snapshot(heartRate: 19))
        invalidSnapshots.append(snapshot(heartRate: 251))
        invalidSnapshots.append(snapshot(activeCalories: .nan))
        invalidSnapshots.append(snapshot(activeCalories: .infinity))
        invalidSnapshots.append(snapshot(activeCalories: -0.1))
        invalidSnapshots.append(snapshot(activeCalories: 100_001))
        invalidSnapshots.append(snapshot(distanceMeters: .nan))
        invalidSnapshots.append(snapshot(distanceMeters: .infinity))
        invalidSnapshots.append(snapshot(distanceMeters: -1))
        invalidSnapshots.append(snapshot(distanceMeters: 1_000_001))

        #expect(invalidSnapshots.allSatisfy { !$0.isValid })
    }

    @Test("Accepts an omitted heart rate")
    func optionalHeartRate() {
        #expect(snapshot(heartRate: nil).isValid)
    }

    @Test("Rejects missing, whitespace-only, and oversized exercise names")
    func rejectsInvalidExerciseNames() {
        #expect(!snapshot(exerciseName: "").isValid)
        #expect(!snapshot(exerciseName: " \n\t ").isValid)
        #expect(!snapshot(exerciseName: String(repeating: "x", count: 201)).isValid)
        #expect(snapshot(exerciseName: String(repeating: "x", count: 200)).isValid)
    }

    @Test("Rejects an update timestamp before the workout start")
    func rejectsTimestampBeforeStart() {
        #expect(!snapshot(updatedAt: startedAt.addingTimeInterval(-1)).isValid)
    }

    @Test("Running elapsed time advances while paused elapsed time stays fixed")
    func elapsedByPhase() {
        let updatedAt = startedAt.addingTimeInterval(300)
        let running = snapshot(phase: .running, updatedAt: updatedAt, elapsedSeconds: 125)
        let paused = snapshot(phase: .paused, updatedAt: updatedAt, elapsedSeconds: 125)
        let later = updatedAt.addingTimeInterval(30)

        #expect(running.elapsed(at: later) == 155)
        #expect(paused.elapsed(at: later) == 125)
        #expect(running.elapsed(at: updatedAt.addingTimeInterval(-5)) == 125)
    }

    @Test("Derives the system timer start date from the latest elapsed snapshot")
    func timerStartDate() {
        let updatedAt = startedAt.addingTimeInterval(300)
        let value = snapshot(updatedAt: updatedAt, elapsedSeconds: 125)

        #expect(value.timerStartDate == updatedAt.addingTimeInterval(-125))
    }
}
