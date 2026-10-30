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
        exerciseName: String = "Outdoor Run",
        exerciseIconName: String? = nil,
        workoutKind: WatchWorkoutSnapshot.WorkoutKind? = nil,
        supportsDistance: Bool? = nil,
        currentSetWeightKg: Double? = nil
    ) -> WatchWorkoutSnapshot {
        WatchWorkoutSnapshot(
            startedAt: startedAt,
            updatedAt: updatedAt ?? startedAt.addingTimeInterval(300),
            exerciseName: exerciseName,
            elapsedSeconds: elapsedSeconds,
            phase: phase,
            heartRate: heartRate,
            activeCalories: activeCalories,
            distanceMeters: distanceMeters,
            exerciseIconName: exerciseIconName,
            workoutKind: workoutKind,
            supportsDistance: supportsDistance,
            currentSetWeightKg: currentSetWeightKg
        )
    }

    @Test("Round trips through JSON")
    func jsonRoundTrip() throws {
        let original = snapshot(exerciseIconName: WorkoutActivityType.running.iconName)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WatchWorkoutSnapshot.self, from: data)

        #expect(decoded == original)
        #expect(decoded.isValid)
    }

    @Test("Older payloads without an icon remain decodable")
    func legacyPayload() throws {
        let data = try JSONEncoder().encode(snapshot())
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["exerciseIconName"] == nil)
        let decoded = try JSONDecoder().decode(WatchWorkoutSnapshot.self, from: data)
        #expect(decoded.exerciseIconName == nil)
        #expect(decoded.isValid)
        #expect(decoded.phaseIconName(isStale: false) == "figure")
    }

    @Test("Older payloads without workout metadata remain decodable")
    func legacyWorkoutMetadataPayload() throws {
        let data = try JSONEncoder().encode(snapshot())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "workoutKind")
        object.removeValue(forKey: "supportsDistance")
        object.removeValue(forKey: "currentSetWeightKg")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(WatchWorkoutSnapshot.self, from: legacyData)
        #expect(decoded.workoutKind == nil)
        #expect(decoded.supportsDistance == nil)
        #expect(decoded.currentSetWeightKg == nil)
        #expect(decoded.isValid)
    }

    @Test("Current-set weight preserves explicit zero and validates bounds", arguments: [0.0, 500.0])
    func currentSetWeightBoundaries(weight: Double) throws {
        let original = snapshot(currentSetWeightKg: weight)
        let decoded = try JSONDecoder().decode(WatchWorkoutSnapshot.self, from: JSONEncoder().encode(original))
        #expect(decoded.currentSetWeightKg == weight)
        #expect(decoded.isValid)
    }

    @Test("Missing current-set weight remains distinct from explicit zero")
    func currentSetWeightMissingAndZero() {
        #expect(snapshot(currentSetWeightKg: nil).currentSetWeightKg == nil)
        #expect(snapshot(currentSetWeightKg: 0).currentSetWeightKg == 0)
    }

    @Test("Older receivers can ignore the additional icon field")
    func legacyReceiver() throws {
        struct LegacySnapshot: Decodable {
            let exerciseName: String
            let phase: WatchWorkoutSnapshot.Phase
            let elapsedSeconds: TimeInterval
        }
        let original = snapshot(exerciseIconName: WorkoutActivityType.running.iconName)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LegacySnapshot.self, from: data)
        #expect(decoded.exerciseName == original.exerciseName)
        #expect(decoded.phase == original.phase)
        #expect(decoded.elapsedSeconds == original.elapsedSeconds)
    }

    @Test("Workout symbols use the existing canonical mapping", arguments: [
        WorkoutActivityType.running, .walking, .cycling, .swimming, .yoga,
        .rowing, .traditionalStrengthTraining, .functionalStrengthTraining
    ])
    func workoutSymbols(activityType: WorkoutActivityType) throws {
        let original = snapshot(exerciseIconName: activityType.iconName)
        let decoded = try JSONDecoder().decode(WatchWorkoutSnapshot.self, from: JSONEncoder().encode(original))
        #expect(decoded.phaseIconName(isStale: false) == activityType.iconName)
        #expect(decoded.isValid)
    }

    @Test("Workout identity stays stable when the current exercise symbol changes")
    func symbolChange() {
        let original = snapshot(exerciseIconName: WorkoutActivityType.running.iconName)
        var changed = original
        changed.exerciseIconName = WorkoutActivityType.cycling.iconName
        #expect(changed != original)
        #expect(changed.isSameWorkout(as: original))
        #expect(changed.phaseIconName(isStale: false) == "figure.outdoor.cycle")
    }

    @Test("Missing or invalid icon metadata uses the generic figure", arguments: [
        nil, "", " \n\t ", String(repeating: "x", count: 101)
    ] as [String?])
    func iconFallback(icon: String?) {
        let value = snapshot(exerciseIconName: icon)
        #expect(value.isValid)
        #expect(value.phaseIconName(isStale: false) == "figure")
    }

    @Test("Status symbols take priority over the exercise", arguments: [
        WatchWorkoutSnapshot.Phase.running, .paused, .ended
    ])
    func statusSymbolPriority(phase: WatchWorkoutSnapshot.Phase) {
        let value = snapshot(phase: phase, exerciseIconName: WorkoutActivityType.running.iconName)
        let expected: String = switch phase {
        case .running: "figure.run"
        case .paused: "pause.fill"
        case .ended: "checkmark"
        }
        #expect(value.phaseIconName(isStale: false) == expected)
        #expect(value.phaseIconName(isStale: true) == "wifi.slash")
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
        invalidSnapshots.append(snapshot(currentSetWeightKg: .nan))
        invalidSnapshots.append(snapshot(currentSetWeightKg: .infinity))
        invalidSnapshots.append(snapshot(currentSetWeightKg: -0.1))
        invalidSnapshots.append(snapshot(currentSetWeightKg: 500.1))

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

    @Test("Workout identity uses the exact Watch start, including closely spaced workouts")
    func workoutIdentity() {
        let current = snapshot()
        var other = current
        #expect(current.isSameWorkout(as: other))
        other.startedAt = current.startedAt.addingTimeInterval(0.001)
        #expect(!current.isSameWorkout(as: other))
        other.startedAt = current.startedAt.addingTimeInterval(1.999)
        #expect(!current.isSameWorkout(as: other))
        other.startedAt = current.startedAt.addingTimeInterval(2)
        #expect(!current.isSameWorkout(as: other))
        other.startedAt = current.startedAt.addingTimeInterval(-2)
        #expect(!current.isSameWorkout(as: other))
    }

    @Test("Older lifecycle messages cannot replace a newer Watch session state")
    func ordersWorkoutLifecycle() {
        var ordering = WatchWorkoutLifecycleOrdering()
        let first = startedAt
        let newer = startedAt.addingTimeInterval(1)
        let legacy = ordering.accept(nil)
        let initial = ordering.accept(first)
        let replacement = ordering.accept(newer)
        let delayedEnd = ordering.accept(first)
        let delayedLegacy = ordering.accept(nil)
        let duplicate = ordering.accept(newer)
        let invalid = ordering.accept(Date(timeIntervalSince1970: .infinity))
        #expect(legacy && initial && replacement && duplicate)
        #expect(!delayedEnd && !delayedLegacy && !invalid)
        #expect(ordering.latestUpdate == newer)
    }
}
