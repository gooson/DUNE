import Foundation
import HealthKit
import Testing
@testable import DUNEWatch

@Suite("Watch session identity recovery", .serialized)
@MainActor
struct WorkoutManagerSessionRecoveryTests {
    private let recoveryKey = "com.raftel.dailve.workoutRecovery"
    private let dismissedWorkoutKey = "com.raftel.dailve.dismissedWorkoutStartDate"
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Stair recovery without a usable snapshot keeps single-workout saving", arguments: [false, true])
    func missingOrCorruptSnapshot(corrupt: Bool) {
        withRecoveryDefaults {
            if corrupt { UserDefaults.standard.set(Data("invalid".utf8), forKey: recoveryKey) }
            let manager = WorkoutManager.shared
            manager.restoreRecoveredSessionState(
                .running, at: start.addingTimeInterval(2_400),
                configuration: configuration(.stairClimbing), startDate: start
            )

            #expect(manager.workoutMode == .cardio(activityType: .stairClimbing, isOutdoor: false))
            #expect(!manager.isRecoveredSession)
            #expect(manager.templateSnapshot == nil)
            #expect(manager.startDate == start)
            #expect(manager.activeElapsedTime(at: start.addingTimeInterval(2_400)) == 2_400)
        }
    }

    @Test("A legacy snapshot without workout mode uses the live session configuration")
    func legacySnapshotWithoutMode() throws {
        try withRecoveryDefaults {
            try storeSnapshot(startDate: start)
            let manager = WorkoutManager.shared
            manager.restoreRecoveredSessionState(
                .running, at: start.addingTimeInterval(600),
                configuration: configuration(.running, outdoor: true), startDate: start
            )

            #expect(manager.workoutMode == .cardio(activityType: .running, isOutdoor: true))
            #expect(!manager.isRecoveredSession)
        }
    }

    @Test("Single-workout modes outside the cardio category are preserved", arguments: [
        HKWorkoutActivityType.flexibility, .swimming, .functionalStrengthTraining
    ])
    func nonTemplateActivities(activity: HKWorkoutActivityType) {
        withRecoveryDefaults {
            let manager = WorkoutManager.shared
            manager.restoreRecoveredSessionState(
                .running, at: start, configuration: configuration(activity), startDate: start
            )

            #expect(manager.workoutMode == .cardio(
                activityType: WorkoutActivityType(healthKit: activity), isOutdoor: false
            ))
            #expect(!manager.isRecoveredSession)
        }
    }

    @Test("Missing strength sets remain an explicit recovery failure")
    func missingStrengthTemplate() {
        withRecoveryDefaults {
            let manager = WorkoutManager.shared
            manager.restoreRecoveredSessionState(
                .running, at: start,
                configuration: configuration(.traditionalStrengthTraining), startDate: start
            )

            #expect(manager.workoutMode == .strength)
            #expect(manager.templateSnapshot == nil)
            #expect(manager.isRecoveredSession)
        }
    }

    @Test("A matching strength template and its completed sets survive recovery")
    func matchingStrengthTemplate() throws {
        try withRecoveryDefaults {
            try storeSnapshot(startDate: start, includesStrengthTemplate: true)
            let manager = WorkoutManager.shared
            manager.restoreRecoveredSessionState(
                .running, at: start.addingTimeInterval(600),
                configuration: configuration(.traditionalStrengthTraining), startDate: start
            )

            #expect(manager.workoutMode == .strength)
            #expect(manager.templateSnapshot?.entries.first?.exerciseDefinitionID == "barbell-squat")
            #expect(manager.completedSetsData.first?.first?.reps == 8)
            #expect(!manager.isRecoveredSession)
        }
    }

    @Test("A different workout's snapshot cannot restore its template or pause totals")
    func staleSnapshot() throws {
        try withRecoveryDefaults {
            try storeSnapshot(startDate: start.addingTimeInterval(-3_600), includesStrengthTemplate: true)
            let manager = WorkoutManager.shared
            manager.restoreRecoveredSessionState(
                .running, at: start.addingTimeInterval(600),
                configuration: configuration(.stairClimbing), startDate: start
            )

            #expect(manager.workoutMode == .cardio(activityType: .stairClimbing, isOutdoor: false))
            #expect(manager.templateSnapshot == nil)
            #expect(manager.completedSetsData.isEmpty)
            #expect(manager.activeElapsedTime(at: start.addingTimeInterval(600)) == 600)
        }
    }

    @Test("Paused recovery persists the real mode and start before pause accounting")
    func pausedRecoveryPersistsIdentity() throws {
        try withRecoveryDefaults {
            let manager = WorkoutManager.shared
            let now = start.addingTimeInterval(2_400)
            manager.restoreRecoveredSessionState(
                .paused, at: now, configuration: configuration(.stairClimbing), startDate: start
            )
            #expect(manager.isPaused)
            #expect(manager.activeElapsedTime(at: now.addingTimeInterval(60)) == 2_400)

            let saved = try #require(UserDefaults.standard.data(forKey: recoveryKey))
            manager.reset()
            UserDefaults.standard.set(saved, forKey: recoveryKey)
            let restored = WorkoutManager.shared
            restored.restoreRecoveredSessionState(.paused, at: now.addingTimeInterval(60))
            #expect(restored.workoutMode == .cardio(activityType: .stairClimbing, isOutdoor: false))
            #expect(restored.startDate == start)
            #expect(restored.activeElapsedTime(at: now.addingTimeInterval(60)) == 2_400)
        }
    }

    @Test("Dismissing an ended workout survives reset and rejects that workout on return")
    func dismissedWorkoutIsNotRecovered() async throws {
        try await withRecoveryDefaults {
            let manager = WorkoutManager.shared
            try await manager.startCardioSession(activityType: .stairClimbing, isOutdoor: false)
            let startedAt = try #require(manager.startDate)
            manager.end()
            manager.reset()

            #expect(UserDefaults.standard.data(forKey: recoveryKey) == nil)
            #expect(UserDefaults.standard.object(forKey: dismissedWorkoutKey) as? Date == startedAt)
            #expect(!manager.shouldRecoverWorkout(startDate: startedAt))
            // Another reset or a fresh view must not erase the persisted acknowledgement.
            manager.reset()
            #expect(!manager.shouldRecoverWorkout(startDate: startedAt))
            #expect(manager.shouldRecoverWorkout(startDate: startedAt.addingTimeInterval(600)))
            #expect(!manager.isSessionEnded)
            #expect(!manager.isActive)
        }
    }

    @Test("Resetting an active workout does not acknowledge an unsaved workout")
    func activeWorkoutRemainsRecoverable() async throws {
        try await withRecoveryDefaults {
            let manager = WorkoutManager.shared
            try await manager.startCardioSession(activityType: .stairClimbing, isOutdoor: false)
            let startedAt = try #require(manager.startDate)
            manager.reset()

            #expect(UserDefaults.standard.object(forKey: dismissedWorkoutKey) == nil)
            #expect(manager.shouldRecoverWorkout(startDate: startedAt))
        }
    }

    private func configuration(_ activity: HKWorkoutActivityType, outdoor: Bool = false) -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity
        configuration.locationType = outdoor ? .outdoor : .indoor
        return configuration
    }

    private func storeSnapshot(startDate: Date, includesStrengthTemplate: Bool = false) throws {
        var snapshot: [String: Any] = [
            "exerciseIndex": 0, "setIndex": 0, "completedSets": [],
            "startDate": startDate.timeIntervalSinceReferenceDate,
            "machineLevelWeightedSeconds": 0, "machineLevelWeightedSum": 0,
            "pausedDuration": 120
        ]
        if includesStrengthTemplate {
            let template = WorkoutSessionTemplate(name: "Strength", entries: [TemplateEntry(
                exerciseDefinitionID: "barbell-squat", exerciseName: "Squat",
                defaultSets: 3, defaultReps: 8, defaultWeightKg: 40
            )])
            let sets = [[CompletedSetData(
                setNumber: 1, weight: 40, reps: 8, duration: nil,
                completedAt: startDate.addingTimeInterval(60)
            )]]
            snapshot["template"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(template))
            snapshot["completedSets"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(sets))
        }
        UserDefaults.standard.set(try JSONSerialization.data(withJSONObject: snapshot), forKey: recoveryKey)
    }

    private func withRecoveryDefaults(_ operation: () throws -> Void) rethrows {
        let previous = UserDefaults.standard.data(forKey: recoveryKey)
        let previousDismissal = UserDefaults.standard.object(forKey: dismissedWorkoutKey)
        WorkoutManager.shared.reset()
        UserDefaults.standard.removeObject(forKey: dismissedWorkoutKey)
        defer {
            WorkoutManager.shared.reset()
            UserDefaults.standard.removeObject(forKey: dismissedWorkoutKey)
            if let previousDismissal { UserDefaults.standard.set(previousDismissal, forKey: dismissedWorkoutKey) }
            if let previous { UserDefaults.standard.set(previous, forKey: recoveryKey) }
        }
        try operation()
    }

    private func withRecoveryDefaults(_ operation: () async throws -> Void) async rethrows {
        let previous = UserDefaults.standard.data(forKey: recoveryKey)
        let previousDismissal = UserDefaults.standard.object(forKey: dismissedWorkoutKey)
        WorkoutManager.shared.reset()
        UserDefaults.standard.removeObject(forKey: dismissedWorkoutKey)
        defer {
            WorkoutManager.shared.reset()
            UserDefaults.standard.removeObject(forKey: dismissedWorkoutKey)
            if let previousDismissal { UserDefaults.standard.set(previousDismissal, forKey: dismissedWorkoutKey) }
            if let previous { UserDefaults.standard.set(previous, forKey: recoveryKey) }
        }
        try await operation()
    }
}
