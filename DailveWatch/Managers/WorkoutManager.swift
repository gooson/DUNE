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

    // MARK: - Live Metrics

    private(set) var heartRate: Double = 0
    private(set) var activeCalories: Double = 0

    /// Running sum and count for average HR calculation.
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

    // MARK: - Workout Data

    private(set) var template: WorkoutTemplate?
    private(set) var currentExerciseIndex: Int = 0
    private(set) var currentSetIndex: Int = 0
    private(set) var completedSetsData: [[CompletedSetData]] = []

    var currentEntry: TemplateEntry? {
        guard let template, currentExerciseIndex < template.exerciseEntries.count else { return nil }
        return template.exerciseEntries[currentExerciseIndex]
    }

    var totalExercises: Int { template?.exerciseEntries.count ?? 0 }

    var isLastSet: Bool {
        guard let entry = currentEntry else { return true }
        return currentSetIndex >= entry.defaultSets - 1
    }

    var isLastExercise: Bool {
        guard let template else { return true }
        return currentExerciseIndex >= template.exerciseEntries.count - 1
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

    func startWorkout(with template: WorkoutTemplate) async throws {
        self.template = template
        self.currentExerciseIndex = 0
        self.currentSetIndex = 0
        self.completedSetsData = Array(repeating: [], count: template.exerciseEntries.count)
        self.heartRateSamples = []

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

        // Notify iPhone via WatchConnectivity
        WatchConnectivityManager.shared.sendWorkoutStarted(templateName: template.name)
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
    }

    func advanceToNextSet() {
        guard let entry = currentEntry else { return }
        if currentSetIndex < entry.defaultSets - 1 {
            currentSetIndex += 1
        }
    }

    func advanceToNextExercise() {
        guard let template else { return }
        if currentExerciseIndex < template.exerciseEntries.count - 1 {
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
        template = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        completedSetsData = []
        heartRate = 0
        activeCalories = 0
        heartRateSamples = []
        isPaused = false
        isSessionEnded = false
        startDate = nil
    }

    // MARK: - Recovery

    func recoverSession() async {
        do {
            let recovered = try await healthStore.recoverActiveWorkoutSession()
            session = recovered
            session?.delegate = self
        } catch {
            // No active session to recover
        }
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
                    try await builder?.finishWorkout()
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

struct CompletedSetData: Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let completedAt: Date
}
