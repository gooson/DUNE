import Foundation
import HealthKit
import Observation
import OSLog

/// Manages HKWorkoutSession + HKLiveWorkoutBuilder for Watch workout tracking.
/// Provides real-time heart rate, calorie, and session state.
/// Supports both strength (weight x reps) and cardio (distance+pace) modes.
@Observable
@MainActor
final class WorkoutManager: NSObject {
    static let shared = WorkoutManager()
    nonisolated private static let logger = Logger(subsystem: "com.raftel.dailve", category: "WatchWorkout")
    nonisolated private static var isSimulatorRuntime: Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }

    let healthStore = HKHealthStore()

    // MARK: - Session State

    private(set) var session: HKWorkoutSession?
    private(set) var builder: HKLiveWorkoutBuilder?
    private(set) var isSimulatedSessionActive = false

    var isActive: Bool { (session != nil || isSimulatedSessionActive) && !isSessionEnded }
    private(set) var isPaused = false
    private(set) var isSessionEnded = false
    /// True while HKLiveWorkoutBuilder is finishing and workout UUID is being resolved.
    private(set) var isFinalizingWorkout = false
    /// Timeout watchdog for flaky simulator callback paths.
    private var finalizationTimeoutTask: Task<Void, Never>?
    /// Ensures `workoutEnded` signal is sent only once per session.
    private var didNotifyWorkoutEnded = false
    private(set) var startDate: Date?
    /// Total paused time accumulated during current session.
    private var pausedDuration: TimeInterval = 0
    /// Pause start timestamp while session is currently paused.
    private var pauseStart: Date?

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

    /// Active elapsed time excluding paused intervals.
    var activeElapsedTime: TimeInterval {
        activeElapsedTime(at: Date())
    }

    /// Active elapsed time using an explicit clock value.
    func activeElapsedTime(at now: Date) -> TimeInterval {
        WorkoutElapsedTime.activeElapsedTime(
            startDate: startDate,
            pausedDuration: pausedDuration,
            pauseStart: pauseStart,
            isPaused: isPaused,
            now: now
        )
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

    func requestAuthorization(timeout seconds: TimeInterval = 10) async throws {
        if Self.isSimulatorRuntime {
            // HealthKit authorization/workout sessions are unreliable on watch simulator.
            // Use simulator fallback session flow for development and UI verification.
            Self.logger.info("Skipping HealthKit authorization on watch simulator")
            return
        }

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

        Self.logger.info("Requesting HealthKit authorization for workout session")
        try await runWithTimeout(
            seconds: seconds,
            timeoutError: WorkoutStartupError.authorizationTimedOut
        ) {
            try await self.healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
        }

        let workoutType = HKQuantityType.workoutType()
        guard healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized else {
            throw WorkoutStartupError.authorizationNotGranted
        }
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
        let previousTemplateSnapshot = templateSnapshot
        let previousExerciseIndex = currentExerciseIndex
        let previousSetIndex = currentSetIndex
        let previousCompletedSets = completedSetsData
        let previousExtraSets = extraSetsPerExercise

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
            templateSnapshot = previousTemplateSnapshot
            currentExerciseIndex = previousExerciseIndex
            currentSetIndex = previousSetIndex
            completedSetsData = previousCompletedSets
            extraSetsPerExercise = previousExtraSets
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
        self.finalizationTimeoutTask?.cancel()
        self.finalizationTimeoutTask = nil
        self.didNotifyWorkoutEnded = false
        self.healthKitWorkoutUUID = nil
        self.isRecoveredSession = false
        self.isSimulatedSessionActive = false
        self.pausedDuration = 0
        self.pauseStart = nil

        if Self.isSimulatorRuntime {
            startSimulatedSession(templateName: templateName)
            return
        }

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

        do {
            newSession.prepare()
            let now = Date()
            startDate = now
            newSession.startActivity(with: now)
            try await runWithTimeout(
                seconds: 10,
                timeoutError: WorkoutStartupError.beginCollectionTimedOut
            ) {
                try await newBuilder.beginCollection(at: now)
            }

            // Persist recovery state
            persistRecoveryState()

            // Notify iPhone via WatchConnectivity
            WatchConnectivityManager.shared.sendWorkoutStarted(templateName: templateName)
        } catch {
            Self.logger.error("Failed to start HK session: \(String(describing: error), privacy: .public)")
            newSession.end()
            session = nil
            builder = nil
            isPaused = false
            isSessionEnded = false
            startDate = nil
            isSimulatedSessionActive = false
            pausedDuration = 0
            pauseStart = nil
            throw error
        }
    }

    /// Simulator-only workout path for development when HealthKit session APIs are unavailable.
    private func startSimulatedSession(templateName: String) {
        Self.logger.info("Starting simulated workout session")
        session = nil
        builder = nil
        isSimulatedSessionActive = true
        isPaused = false
        isSessionEnded = false
        isFinalizingWorkout = false
        startDate = Date()
        pausedDuration = 0
        pauseStart = nil
        persistRecoveryState()
        WatchConnectivityManager.shared.sendWorkoutStarted(templateName: templateName)
    }

    func pause() {
        if let session {
            beginPause(at: Date())
            session.pause()
            return
        }
        if isSimulatedSessionActive {
            beginPause(at: Date())
        }
    }

    func resume() {
        if let session {
            endPause(at: Date())
            session.resume()
            return
        }
        if isSimulatedSessionActive {
            endPause(at: Date())
        }
    }

    func end() {
        guard !isSessionEnded else { return }
        endPause(at: Date())

        if isSimulatedSessionActive {
            isPaused = false
            isSessionEnded = true
            isFinalizingWorkout = false
            isSimulatedSessionActive = false
            notifyWorkoutEndedIfNeeded()
            return
        }

        guard session != nil else { return }

        // Transition UI immediately even when simulator callbacks are delayed.
        isSessionEnded = true
        isFinalizingWorkout = session != nil
        notifyWorkoutEndedIfNeeded()

        if isFinalizingWorkout {
            startFinalizationTimeoutWatchdog()
        }
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

    /// Record rest duration on the last completed set for the current exercise.
    func recordRestDuration(_ duration: TimeInterval) {
        guard currentExerciseIndex < completedSetsData.count else { return }
        let lastIdx = completedSetsData[currentExerciseIndex].count - 1
        guard lastIdx >= 0 else { return }
        completedSetsData[currentExerciseIndex][lastIdx].restDuration = duration
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
        finalizationTimeoutTask?.cancel()
        finalizationTimeoutTask = nil
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
        isSimulatedSessionActive = false
        didNotifyWorkoutEnded = false
        isRecoveredSession = false
        startDate = nil
        healthKitWorkoutUUID = nil
        pausedDuration = 0
        pauseStart = nil
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

    /// Wraps async startup operations with a timeout to avoid indefinite loading
    /// when HealthKit callbacks are delayed or missing (common in simulators).
    private func runWithTimeout(
        seconds: TimeInterval,
        timeoutError: Error,
        operation: @escaping @MainActor () async throws -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var isResolved = false
            var operationTask: Task<Void, Never>?
            var timeoutTask: Task<Void, Never>?

            func resolve(_ result: Result<Void, Error>) {
                guard !isResolved else { return }
                isResolved = true
                operationTask?.cancel()
                timeoutTask?.cancel()
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            operationTask = Task { @MainActor in
                do {
                    try await operation()
                    resolve(.success(()))
                } catch {
                    resolve(.failure(error))
                }
            }

            timeoutTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                resolve(.failure(timeoutError))
            }
        }
    }

    private func notifyWorkoutEndedIfNeeded() {
        guard !didNotifyWorkoutEnded else { return }
        didNotifyWorkoutEnded = true
        WatchConnectivityManager.shared.sendWorkoutEnded()
    }

    private func startFinalizationTimeoutWatchdog(timeout seconds: TimeInterval = 6) {
        finalizationTimeoutTask?.cancel()
        finalizationTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            guard self.isFinalizingWorkout else { return }
            Self.logger.error("Workout finalization timed out; allowing summary completion")
            self.isFinalizingWorkout = false
        }
    }

    private func beginPause(at date: Date) {
        guard pauseStart == nil else {
            isPaused = true
            return
        }
        pauseStart = date
        isPaused = true
    }

    private func endPause(at date: Date) {
        if let pauseStart {
            let delta = date.timeIntervalSince(pauseStart)
            if delta > 0 {
                pausedDuration += delta
            }
            self.pauseStart = nil
        }
        isPaused = false
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
            guard let currentSession = session, workoutSession === currentSession else { return }
            switch toState {
            case .running:
                endPause(at: date)
            case .paused:
                beginPause(at: date)
            case .ended:
                endPause(at: date)
                isSessionEnded = true
                isFinalizingWorkout = true
                notifyWorkoutEndedIfNeeded()
                startFinalizationTimeoutWatchdog()
                defer {
                    finalizationTimeoutTask?.cancel()
                    finalizationTimeoutTask = nil
                    isFinalizingWorkout = false
                }
                do {
                    try await builder?.endCollection(at: date)
                    let workout = try await builder?.finishWorkout()
                    if let workoutID = workout?.uuid.uuidString, !workoutID.isEmpty {
                        healthKitWorkoutUUID = workoutID
                    }
                } catch {
                    Self.logger.error("Failed to finish workout: \(error.localizedDescription, privacy: .public)")
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
        Task { @MainActor in
            guard let currentSession = session, workoutSession === currentSession else { return }
            Self.logger.error("Workout session failed: \(error.localizedDescription, privacy: .public)")
            finalizationTimeoutTask?.cancel()
            finalizationTimeoutTask = nil
            isFinalizingWorkout = false
        }
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

    /// Recalculates current pace (sec/km) from total distance and active elapsed time.
    @MainActor
    private func updatePace() {
        guard startDate != nil else { return }
        let elapsed = activeElapsedTime(at: Date())
        guard elapsed > 0 else {
            currentPace = 0
            return
        }
        let km = distance / 1000.0
        guard km > 0.01 else {
            currentPace = 0
            return
        }
        currentPace = elapsed / km
    }
}

enum WorkoutElapsedTime {
    static func activeElapsedTime(
        startDate: Date?,
        pausedDuration: TimeInterval,
        pauseStart: Date?,
        isPaused: Bool,
        now: Date
    ) -> TimeInterval {
        guard let startDate else { return 0 }
        var elapsed = now.timeIntervalSince(startDate) - pausedDuration
        if isPaused, let pauseStart {
            elapsed -= now.timeIntervalSince(pauseStart)
        }
        return Swift.max(elapsed, 0)
    }
}

// MARK: - Data Types

struct CompletedSetData: Codable, Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let completedAt: Date
    /// Rest timer total (including +30s adjustments) used after this set, in seconds.
    var restDuration: TimeInterval?
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

enum WorkoutStartupError: LocalizedError {
    case authorizationTimedOut
    case authorizationNotGranted
    case beginCollectionTimedOut

    var errorDescription: String? {
        String(localized: "Could not start workout. Please try again.")
    }
}
