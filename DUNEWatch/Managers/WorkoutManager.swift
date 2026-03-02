import Foundation
import HealthKit
import Observation

/// Manages HKWorkoutSession + HKLiveWorkoutBuilder for Watch workout tracking.
/// Provides real-time heart rate, calorie, and session state.
/// Supports both strength (weight x reps) and cardio (distance+pace) modes.
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
    /// True while HKLiveWorkoutBuilder is finishing and workout UUID is being resolved.
    private(set) var isFinalizingWorkout = false
    private(set) var startDate: Date?

    /// UUID of the saved HKWorkout, captured after finishWorkout().
    /// Used to link ExerciseRecord.healthKitWorkoutID for HealthKit data retrieval.
    private(set) var healthKitWorkoutUUID: String?

    /// True when session was recovered from crash/termination without template data.
    private(set) var isRecoveredSession = false

    /// Current workout mode — determines which metrics view is shown.
    private(set) var workoutMode: WorkoutMode = .strength

    /// Whether the current session is a cardio workout.
    var isCardioMode: Bool { workoutMode.isCardio }

    // MARK: - Live Metrics

    private(set) var heartRate: Double = 0
    private(set) var activeCalories: Double = 0

    /// Total distance in meters (cardio mode only).
    private(set) var distance: Double = 0

    /// Current pace in seconds per kilometer (cardio mode only).
    private(set) var currentPace: Double = 0

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

    /// Distance in kilometers (convenience for UI display).
    var distanceKm: Double { distance / 1000.0 }

    /// Formatted pace string "M:SS" (returns "--:--" when no distance yet).
    var formattedPace: String {
        guard currentPace > 0, currentPace.isFinite, currentPace < 3600 else { return "--:--" }
        let mins = Int(currentPace) / 60
        let secs = Int(currentPace) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Workout Data (plain struct snapshot, not @Model reference — M6)

    /// Snapshot of template data taken at workout start. Not a SwiftData @Model reference.
    private(set) var templateSnapshot: WorkoutSessionTemplate?
    private(set) var currentExerciseIndex: Int = 0
    private(set) var currentSetIndex: Int = 0
    private(set) var completedSetsData: [[CompletedSetData]] = []

    /// Extra sets added beyond the default per exercise (indexed by exercise index).
    private(set) var extraSetsPerExercise: [Int: Int] = [:]

    var currentEntry: TemplateEntry? {
        guard let snapshot = templateSnapshot,
              currentExerciseIndex < snapshot.entries.count else { return nil }
        return snapshot.entries[currentExerciseIndex]
    }

    var totalExercises: Int { templateSnapshot?.entries.count ?? 0 }

    /// Total sets for the current exercise (default + extra).
    var effectiveTotalSets: Int {
        guard let snapshot = templateSnapshot,
              currentExerciseIndex < snapshot.entries.count else { return 0 }
        let entry = snapshot.entries[currentExerciseIndex]
        let extra = extraSetsPerExercise[currentExerciseIndex] ?? 0
        return entry.defaultSets + extra
    }

    var isLastSet: Bool {
        return currentSetIndex >= effectiveTotalSets - 1
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
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming)
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
        try await startStrengthSession(with: snapshot)
    }

    /// Start a workout from a pre-built snapshot (Quick Start flow — strength).
    func startQuickWorkout(with snapshot: WorkoutSessionTemplate) async throws {
        try await startStrengthSession(with: snapshot)
    }

    /// Start a cardio workout session with appropriate HK activity type.
    func startCardioSession(activityType: WorkoutActivityType, isOutdoor: Bool) async throws {
        let previousMode = workoutMode
        let previousDistance = distance
        let previousPace = currentPace

        self.workoutMode = .cardio(activityType: activityType, isOutdoor: isOutdoor)
        self.distance = 0
        self.currentPace = 0
        // templateSnapshot is nil for cardio — no set/exercise tracking needed
        self.templateSnapshot = nil
        self.completedSetsData = []
        self.extraSetsPerExercise = [:]

        let config = HKWorkoutConfiguration()
        config.activityType = activityType.hkWorkoutActivityType
        config.locationType = isOutdoor ? .outdoor : .indoor

        do {
            try await startHKSession(config: config, templateName: activityType.typeName)
        } catch {
            // Restore state on failure to prevent inconsistent workoutMode
            workoutMode = previousMode
            distance = previousDistance
            currentPace = previousPace
            throw error
        }
    }

    /// Common strength HK session setup.
    private func startStrengthSession(with snapshot: WorkoutSessionTemplate) async throws {
        self.workoutMode = .strength
        self.templateSnapshot = snapshot
        self.currentExerciseIndex = 0
        self.currentSetIndex = 0
        self.completedSetsData = Array(repeating: [], count: snapshot.entries.count)
        self.extraSetsPerExercise = [:]
        self.distance = 0
        self.currentPace = 0

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        try await startHKSession(config: config, templateName: snapshot.name)
    }

    /// Common HK session setup shared by strength and cardio flows.
    private func startHKSession(config: HKWorkoutConfiguration, templateName: String) async throws {
        self.heartRateSamples = []
        self.isSessionEnded = false
        self.isFinalizingWorkout = false
        self.healthKitWorkoutUUID = nil
        self.isRecoveredSession = false

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
        WatchConnectivityManager.shared.sendWorkoutStarted(templateName: templateName)
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

    /// Wait briefly for HealthKit workout finalization after `.ended` to reduce UUID races.
    func waitForWorkoutFinalization(timeout seconds: TimeInterval = 5) async {
        guard isSessionEnded else { return }
        let deadline = Date().addingTimeInterval(seconds)
        while isFinalizingWorkout, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    // MARK: - Set/Exercise Navigation

    func completeSet(weight: Double?, reps: Int?) {
        // Validate input ranges before recording (mirrors iPhone validation rules)
        let validatedWeight: Double? = weight.flatMap { (0...500).contains($0) ? $0 : nil }
        let validatedReps: Int? = reps.flatMap { (0...1000).contains($0) ? $0 : nil }

        let data = CompletedSetData(
            setNumber: currentSetIndex + 1,
            weight: validatedWeight,
            reps: validatedReps,
            completedAt: Date()
        )
        if currentExerciseIndex < completedSetsData.count {
            completedSetsData[currentExerciseIndex].append(data)
        }
        persistRecoveryState()
    }

    func advanceToNextSet() {
        if currentSetIndex < effectiveTotalSets - 1 {
            currentSetIndex += 1
        }
    }

    /// Add one extra set to the current exercise.
    func addExtraSet() {
        let current = extraSetsPerExercise[currentExerciseIndex] ?? 0
        extraSetsPerExercise[currentExerciseIndex] = current + 1
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
        workoutMode = .strength
        currentExerciseIndex = 0
        currentSetIndex = 0
        completedSetsData = []
        extraSetsPerExercise = [:]
        heartRate = 0
        activeCalories = 0
        distance = 0
        currentPace = 0
        heartRateSamples = []
        isPaused = false
        isSessionEnded = false
        isFinalizingWorkout = false
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

            // Restore distance from builder statistics if cardio session
            if isCardioMode {
                restoreDistanceFromBuilder(recoveredBuilder)
            }

            // If strength mode but template couldn't be restored, mark as recovered session
            if !isCardioMode, templateSnapshot == nil {
                isRecoveredSession = true
            }
        } catch {
            // No active session to recover
        }
    }

    /// Restores distance metric from builder statistics after crash recovery.
    @MainActor
    private func restoreDistanceFromBuilder(_ builder: HKLiveWorkoutBuilder) {
        let distanceTypes: [HKQuantityType] = [
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.distanceWheelchair),
            HKQuantityType(.distanceCrossCountrySkiing),
            HKQuantityType(.distanceDownhillSnowSports)
        ]
        for type in distanceTypes {
            if let stats = builder.statistics(for: type),
               let meters = stats.sumQuantity()?.doubleValue(for: .meter()),
               meters > 0, meters < 500_000 {
                distance = meters
                updatePace()
                break
            }
        }
    }

    // MARK: - Recovery State Persistence

    private static let recoveryKey = "com.raftel.dailve.workoutRecovery"

    private func persistRecoveryState() {
        let state = WorkoutRecoveryState(
            template: templateSnapshot,
            exerciseIndex: currentExerciseIndex,
            setIndex: currentSetIndex,
            completedSets: completedSetsData,
            startDate: startDate,
            workoutMode: workoutMode
        )
        guard let data = try? JSONEncoder().encode(state),
              data.count < 64_000 else { return }
        UserDefaults.standard.set(data, forKey: Self.recoveryKey)
    }

    private func restoreRecoveryState() {
        guard let data = UserDefaults.standard.data(forKey: Self.recoveryKey),
              let state = try? JSONDecoder().decode(WorkoutRecoveryState.self, from: data) else {
            return
        }
        templateSnapshot = state.template
        // Bounds-check restored indices
        let maxExercise = Swift.max(state.completedSets.count - 1, 0)
        currentExerciseIndex = min(state.exerciseIndex, maxExercise)
        currentSetIndex = Swift.max(state.setIndex, 0)
        completedSetsData = state.completedSets
        startDate = state.startDate
        workoutMode = state.workoutMode ?? .strength
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
                isFinalizingWorkout = true
                WatchConnectivityManager.shared.sendWorkoutEnded()
                defer { isFinalizingWorkout = false }
                do {
                    try await builder?.endCollection(at: date)
                    let workout = try await builder?.finishWorkout()
                    if let workoutID = workout?.uuid.uuidString, !workoutID.isEmpty {
                        healthKitWorkoutUUID = workoutID
                    }
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
        // Extract primitive values on the delegate callback thread (before actor hop)
        // to avoid cross-actor access of non-Sendable HKLiveWorkoutBuilder.
        var heartRateValue: Double?
        var caloriesValue: Double?
        var distanceValue: Double?

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let stats = workoutBuilder.statistics(for: quantityType) else { continue }

            switch quantityType {
            case HKQuantityType(.heartRate):
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = stats.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
                if (20...250).contains(bpm) {
                    heartRateValue = bpm
                }

            case HKQuantityType(.activeEnergyBurned):
                let unit = HKUnit.kilocalorie()
                let kcal = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                if kcal >= 0, kcal < 10_000 {
                    caloriesValue = kcal
                }

            case HKQuantityType(.distanceWalkingRunning),
                 HKQuantityType(.distanceCycling),
                 HKQuantityType(.distanceSwimming):
                let meters = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                if meters >= 0, meters < 500_000 {
                    distanceValue = meters
                }

            default:
                break
            }
        }

        // Dispatch only primitive values to MainActor
        Task { @MainActor in
            if let bpm = heartRateValue {
                heartRate = bpm
                heartRateSamples.append(bpm)
            }
            if let kcal = caloriesValue {
                activeCalories = kcal
            }
            if let meters = distanceValue {
                distance = meters
                updatePace()
            }
        }
    }

    /// Recalculates current pace (sec/km) from total distance and elapsed time.
    /// Skips recalculation when paused to avoid inflating pace with paused time.
    @MainActor
    private func updatePace() {
        guard !isPaused else { return }
        guard let start = startDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        let km = distance / 1000.0
        guard km > 0.01 else {
            currentPace = 0
            return
        }
        currentPace = elapsed / km
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
    let template: WorkoutSessionTemplate?
    let exerciseIndex: Int
    let setIndex: Int
    let completedSets: [[CompletedSetData]]
    let startDate: Date?
    let workoutMode: WorkoutMode?
}
