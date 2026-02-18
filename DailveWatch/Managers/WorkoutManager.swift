import Foundation
import HealthKit
import Observation

/// Manages HKWorkoutSession + HKLiveWorkoutBuilder for Watch workout tracking.
/// Provides real-time heart rate, calorie, and session state.
@Observable
@MainActor
final class WorkoutManager: NSObject {
    static let shared = WorkoutManager()

    let healthStore = HKHealthStore()

    // MARK: - Session State

    private(set) var session: HKWorkoutSession?
    private(set) var builder: HKLiveWorkoutBuilder?

    var isActive: Bool { session != nil && !isSessionEnded }
    private(set) var isPaused = false
    private(set) var isSessionEnded = false
    private(set) var startDate: Date?

    /// UUID of the saved HKWorkout, captured after finishWorkout().
    /// Used to link ExerciseRecord.healthKitWorkoutID for HealthKit data retrieval.
    private(set) var healthKitWorkoutUUID: String?

    /// True when session was recovered from crash/termination without template data.
    private(set) var isRecoveredSession = false

    // MARK: - Live Metrics

    private(set) var heartRate: Double = 0
    private(set) var activeCalories: Double = 0

    /// Running samples for average HR calculation.
    private var heartRateSamples: [Double] = []

    /// Average heart rate across the entire session.
    var averageHeartRate: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
    }

    /// Max heart rate recorded during the session.
    var maxHeartRate: Double {
        heartRateSamples.max() ?? 0
    }

    // MARK: - Workout Data (plain struct snapshot, not @Model reference — M6)

    /// Snapshot of template data taken at workout start. Not a SwiftData @Model reference.
    private(set) var templateSnapshot: WorkoutSessionTemplate?
    private(set) var currentExerciseIndex: Int = 0
    private(set) var currentSetIndex: Int = 0
    private(set) var completedSetsData: [[CompletedSetData]] = []

    var currentEntry: TemplateEntry? {
        guard let snapshot = templateSnapshot,
              currentExerciseIndex < snapshot.entries.count else { return nil }
        return snapshot.entries[currentExerciseIndex]
    }

    var totalExercises: Int { templateSnapshot?.entries.count ?? 0 }

    var isLastSet: Bool {
        guard let entry = currentEntry else { return true }
        return currentSetIndex >= entry.defaultSets - 1
    }

    var isLastExercise: Bool {
        guard let snapshot = templateSnapshot else { return true }
        return currentExerciseIndex >= snapshot.entries.count - 1
    }

    /// Last completed set for the current exercise (for weight/reps pre-fill).
    var lastCompletedSetForCurrentExercise: CompletedSetData? {
        guard currentExerciseIndex < completedSetsData.count else { return nil }
        return completedSetsData[currentExerciseIndex].last
    }

    // MARK: - HealthKit Authorization

    func requestAuthorization() async throws {
        let shareTypes: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // MARK: - Session Lifecycle

    /// Start a workout from a SwiftData template (template list flow).
    func startWorkout(with template: WorkoutTemplate) async throws {
        let snapshot = WorkoutSessionTemplate(
            name: template.name,
            entries: template.exerciseEntries
        )
        try await startSession(with: snapshot)
    }

    /// Start a workout from a pre-built snapshot (Quick Start flow).
    func startQuickWorkout(with snapshot: WorkoutSessionTemplate) async throws {
        try await startSession(with: snapshot)
    }

    /// Common HK session setup shared by template and quick-start flows.
    private func startSession(with snapshot: WorkoutSessionTemplate) async throws {
        self.templateSnapshot = snapshot
        self.currentExerciseIndex = 0
        self.currentSetIndex = 0
        self.completedSetsData = Array(repeating: [], count: snapshot.entries.count)
        self.heartRateSamples = []
        self.isRecoveredSession = false

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let newBuilder = newSession.associatedWorkoutBuilder()

        session = newSession
        builder = newBuilder

        newSession.delegate = self
        newBuilder.delegate = self
        newBuilder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )

        newSession.prepare()
        let now = Date()
        startDate = now
        newSession.startActivity(with: now)
        try await newBuilder.beginCollection(at: now)

        // Persist recovery state
        persistRecoveryState()

        // Notify iPhone via WatchConnectivity
        WatchConnectivityManager.shared.sendWorkoutStarted(templateName: snapshot.name)
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    func end() {
        session?.end()
    }

    // MARK: - Set/Exercise Navigation

    func completeSet(weight: Double?, reps: Int?) {
        let data = CompletedSetData(
            setNumber: currentSetIndex + 1,
            weight: weight,
            reps: reps,
            completedAt: Date()
        )
        if currentExerciseIndex < completedSetsData.count {
            completedSetsData[currentExerciseIndex].append(data)
        }
        persistRecoveryState()
    }

    func advanceToNextSet() {
        guard let entry = currentEntry else { return }
        if currentSetIndex < entry.defaultSets - 1 {
            currentSetIndex += 1
        }
    }

    func advanceToNextExercise() {
        guard let snapshot = templateSnapshot else { return }
        if currentExerciseIndex < snapshot.entries.count - 1 {
            currentExerciseIndex += 1
            currentSetIndex = 0
        }
    }

    func skipExercise() {
        advanceToNextExercise()
    }

    func reset() {
        session = nil
        builder = nil
        templateSnapshot = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        completedSetsData = []
        heartRate = 0
        activeCalories = 0
        heartRateSamples = []
        isPaused = false
        isSessionEnded = false
        isRecoveredSession = false
        startDate = nil
        healthKitWorkoutUUID = nil
        clearRecoveryState()
    }

    // MARK: - Recovery

    func recoverSession() async {
        do {
            guard let recovered = try await healthStore.recoverActiveWorkoutSession() else {
                return
            }
            session = recovered
            recovered.delegate = self

            // Restore builder + delegate for live metrics (M4)
            let recoveredBuilder = recovered.associatedWorkoutBuilder()
            builder = recoveredBuilder
            recoveredBuilder.delegate = self

            // Restore template/exercise state from persisted data (C4)
            restoreRecoveryState()

            // If template couldn't be restored, mark as recovered session
            if templateSnapshot == nil {
                isRecoveredSession = true
            }
        } catch {
            // No active session to recover
        }
    }

    // MARK: - Recovery State Persistence

    private static let recoveryKey = "com.dailve.workoutRecovery"

    private func persistRecoveryState() {
        guard let snapshot = templateSnapshot else { return }
        let state = WorkoutRecoveryState(
            template: snapshot,
            exerciseIndex: currentExerciseIndex,
            setIndex: currentSetIndex,
            completedSets: completedSetsData,
            startDate: startDate
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.recoveryKey)
        }
    }

    private func restoreRecoveryState() {
        guard let data = UserDefaults.standard.data(forKey: Self.recoveryKey),
              let state = try? JSONDecoder().decode(WorkoutRecoveryState.self, from: data) else {
            return
        }
        templateSnapshot = state.template
        currentExerciseIndex = state.exerciseIndex
        currentSetIndex = state.setIndex
        completedSetsData = state.completedSets
        startDate = state.startDate
        isRecoveredSession = false
    }

    private func clearRecoveryState() {
        UserDefaults.standard.removeObject(forKey: Self.recoveryKey)
    }

    private override init() {
        super.init()
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                isPaused = false
            case .paused:
                isPaused = true
            case .ended:
                isSessionEnded = true
                WatchConnectivityManager.shared.sendWorkoutEnded()
                do {
                    try await builder?.endCollection(at: date)
                    let workout = try await builder?.finishWorkout()
                    healthKitWorkoutUUID = workout?.uuid.uuidString
                } catch {
                    print("Failed to finish workout: \(error.localizedDescription)")
                }
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // No custom events
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType,
                      let stats = workoutBuilder.statistics(for: quantityType) else { continue }

                switch quantityType {
                case HKQuantityType(.heartRate):
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    let bpm = stats.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
                    if (20...250).contains(bpm) {
                        heartRate = bpm
                        heartRateSamples.append(bpm)
                    }

                case HKQuantityType(.activeEnergyBurned):
                    let unit = HKUnit.kilocalorie()
                    activeCalories = stats.sumQuantity()?.doubleValue(for: unit) ?? 0

                default:
                    break
                }
            }
        }
    }
}

// MARK: - Data Types

struct CompletedSetData: Codable, Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let completedAt: Date
}

/// Plain struct snapshot of WorkoutTemplate data.
/// Avoids holding a SwiftData @Model reference in the singleton (M6).
struct WorkoutSessionTemplate: Codable, Sendable {
    let name: String
    let entries: [TemplateEntry]
}

/// Persisted state for crash recovery (C4).
private struct WorkoutRecoveryState: Codable {
    let template: WorkoutSessionTemplate
    let exerciseIndex: Int
    let setIndex: Int
    let completedSets: [[CompletedSetData]]
    let startDate: Date?
}
