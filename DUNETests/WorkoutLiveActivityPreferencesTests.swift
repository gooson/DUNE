import Foundation
import Testing
@testable import DUNE

@Suite("Workout Live Activity preferences")
struct WorkoutLiveActivityPreferencesTests {
    private func snapshot(
        kind: WatchWorkoutSnapshot.WorkoutKind?,
        supportsDistance: Bool? = nil,
        heartRate: Double? = nil,
        weight: Double? = nil
    ) -> WatchWorkoutSnapshot {
        WatchWorkoutSnapshot(
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_010),
            exerciseName: "Workout",
            elapsedSeconds: 10,
            phase: .running,
            heartRate: heartRate,
            activeCalories: 1,
            distanceMeters: 0,
            workoutKind: kind,
            supportsDistance: supportsDistance,
            currentSetWeightKg: weight
        )
    }

    @Test("Defaults and unknown stored values retain elapsed time and Gold Impact")
    func defaultsAndInvalidStorage() throws {
        let suite = "WorkoutLiveActivityPreferencesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(WorkoutLiveActivityPreferences.read(defaults: defaults).cardioMetric == .elapsedTime)
        #expect(WorkoutLiveActivityPreferences.read(defaults: defaults).strengthMetric == .elapsedTime)
        #expect(WorkoutLiveActivityPreferences.read(defaults: defaults).style == .goldImpact)

        defaults.set("weight", forKey: WorkoutLiveActivityPreferences.cardioMetricKey)
        defaults.set("distance", forKey: WorkoutLiveActivityPreferences.strengthMetricKey)
        defaults.set("unknown", forKey: WorkoutLiveActivityPreferences.styleKey)
        let read = WorkoutLiveActivityPreferences.read(defaults: defaults)
        #expect(read.cardioMetric == .elapsedTime)
        #expect(read.strengthMetric == .elapsedTime)
        #expect(read.style == .goldImpact)
    }

    @Test("Choices persist independently")
    func savesChoices() throws {
        let suite = "WorkoutLiveActivityPreferencesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var preferences = WorkoutLiveActivityPreferences()
        preferences.cardioMetric = .distance
        preferences.strengthMetric = .weight
        preferences.style = .standard
        preferences.save(to: defaults)

        let read = WorkoutLiveActivityPreferences.read(defaults: defaults)
        #expect(read.cardioMetric == .distance)
        #expect(read.strengthMetric == .weight)
        #expect(read.style == .standard)
    }

    @Test("Older snapshots and unavailable distance fall back to elapsed time")
    func missingKindAndDistance() {
        var preferences = WorkoutLiveActivityPreferences()
        preferences.cardioMetric = .distance
        #expect(preferences.resolvedMetric(for: snapshot(kind: nil, supportsDistance: true)) == .elapsedTime)
        #expect(preferences.resolvedMetric(for: snapshot(kind: .cardio)) == .elapsedTime)
        #expect(preferences.resolvedMetric(for: snapshot(kind: .cardio, supportsDistance: false)) == .elapsedTime)
        #expect(preferences.resolvedMetric(for: snapshot(kind: .cardio, supportsDistance: true)) == .distance)
    }

    @Test("Heart rate requires a finite physiological value")
    func heartRateValidation() {
        var preferences = WorkoutLiveActivityPreferences()
        preferences.cardioMetric = .heartRate
        preferences.strengthMetric = .heartRate
        for kind in [WatchWorkoutSnapshot.WorkoutKind.cardio, .strength] {
            for value in [nil, Double.nan, .infinity, 19, 251] as [Double?] {
                #expect(preferences.resolvedMetric(for: snapshot(kind: kind, heartRate: value)) == .elapsedTime)
            }
            #expect(preferences.resolvedMetric(for: snapshot(kind: kind, heartRate: 20)) == .heartRate)
            #expect(preferences.resolvedMetric(for: snapshot(kind: kind, heartRate: 250)) == .heartRate)
        }
    }

    @Test("Current set weight accepts zero and the upper boundary")
    func weightValidation() {
        var preferences = WorkoutLiveActivityPreferences()
        preferences.strengthMetric = .weight
        for value in [nil, Double.nan, .infinity, -1, 501] as [Double?] {
            #expect(preferences.resolvedMetric(for: snapshot(kind: .strength, weight: value)) == .elapsedTime)
        }
        #expect(preferences.resolvedMetric(for: snapshot(kind: .strength, weight: 0)) == .weight)
        #expect(preferences.resolvedMetric(for: snapshot(kind: .strength, weight: 500)) == .weight)
        #expect(preferences.resolvedMetric(for: snapshot(kind: .cardio, weight: 100)) == .elapsedTime)
    }
}
