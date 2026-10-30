import Foundation
import Testing
@testable import DUNE

@Suite("Watch workout Activity content state")
struct WatchWorkoutAttributesTests {
    private var snapshot: WatchWorkoutSnapshot {
        WatchWorkoutSnapshot(
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_010),
            exerciseName: "Strength Training",
            elapsedSeconds: 10,
            phase: .running,
            heartRate: 140,
            activeCalories: 10,
            distanceMeters: 0,
            workoutKind: .strength,
            currentSetWeightKg: 60
        )
    }

    @Test("Current Activity state carries selected preferences")
    func roundTrip() throws {
        var preferences = WorkoutLiveActivityPreferences()
        preferences.cardioMetric = .distance
        preferences.strengthMetric = .weight
        preferences.style = .standard
        let original = WatchWorkoutAttributes.ContentState(
            snapshot: snapshot, preferences: preferences
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchWorkoutAttributes.ContentState.self, from: data)

        #expect(decoded == original)
    }

    @Test("Flat Activity state from earlier versions decodes with safe defaults")
    func legacySnapshot() throws {
        let oldData = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WatchWorkoutAttributes.ContentState.self, from: oldData)

        #expect(decoded.snapshot == snapshot)
        #expect(decoded.preferences == WorkoutLiveActivityPreferences())
    }
}
