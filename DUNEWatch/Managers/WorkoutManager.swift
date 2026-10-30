import CoreLocation
import Foundation
import HealthKit
import Observation
import OSLog
import WatchKit

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
    private let runningVoiceFeedback = RunningVoiceFeedback(speaker: AVRunningVoiceSpeaker())

    var isRunningVoiceFeedbackEnabled: Bool { runningVoiceFeedback.isEnabled }

    func setRunningVoiceFeedbackEnabled(_ enabled: Bool) {
        runningVoiceFeedback.isEnabled = enabled
    }

    var runningFeedbackSettings: RunningFeedbackSettings { runningVoiceFeedback.settings }

    func updateRunningFeedbackSettings(_ settings: RunningFeedbackSettings) {
        runningVoiceFeedback.settings = settings
    }

    private func announceRunning(_ event: RunningVoiceFeedback.Event) {
        guard case .cardio(.running, _) = workoutMode else { return }
        runningVoiceFeedback.announce(event: event)
    }

    // MARK: - Session State

    private(set) var session: HKWorkoutSession?
    private(set) var builder: HKLiveWorkoutBuilder?
    private(set) var isSimulatedSessionActive = false
    private var mirrorStartTask: Task<Void, Never>?
    private var mirrorIntervalTask: Task<Void, Never>?
    private var mirrorSendTask: Task<Void, Never>?
    private var mirrorRetryTask: Task<Void, Never>?
    private var mirroredSession: HKWorkoutSession?
    private var pendingMirrorSnapshot: WatchWorkoutSnapshot?
    private var mirrorGeneration = UUID()
    private var mirrorRetryPolicy = WorkoutMirrorRetryPolicy()
    private var mirrorWorkoutName = String(localized: "Workout")

    var isActive: Bool { (session != nil || isSimulatedSessionActive) && !isSessionEnded }
    private(set) var isPaused = false
    private(set) var isSessionEnded = false
    /// True while HKLiveWorkoutBuilder is finishing and workout UUID is being resolved.
    private(set) var isFinalizingWorkout = false
    /// Timeout watchdog for flaky simulator callback paths.
    private var finalizationTimeoutTask: Task<Void, Never>?
    private var routeRecorder: WorkoutRouteRecorder?
    private var capturedRoute: [WorkoutRoutePoint] = []
    // Completed-workout jobs are independent of session/reset generation and own immutable inputs.
    private var routeSaveJobs: [UUID: WorkoutRouteSaveJob] = [:]
    /// Ensures `workoutEnded` signal is sent only once per session.
    private var didNotifyWorkoutEnded = false
    private(set) var startDate: Date?
    /// Total paused time accumulated during current session.
    private var pausedDuration: TimeInterval = 0
    private var completedDuration: TimeInterval?
    /// Pause start timestamp while session is currently paused.
    private var pauseStart: Date?

    /// UUID of the saved HKWorkout, captured after finishWorkout().
    /// Used to link ExerciseRecord.healthKitWorkoutID for HealthKit data retrieval.
    private(set) var healthKitWorkoutUUID: String?

    /// True when session was recovered from crash/termination without template data.
    private(set) var isRecoveredSession = false

    /// Current workout mode — determines which metrics view is shown.
    private(set) var workoutMode: WorkoutMode = .strength
    /// Session-level cardio unit metadata used by Watch cardio UI.
    private(set) var cardioSecondaryUnit: CardioSecondaryUnit?

    /// Whether the current session is a cardio workout.
    var isCardioMode: Bool { workoutMode.isCardio }
    /// Current no-motion prompt state for cardio sessions.
    private(set) var cardioInactivityPrompt: CardioInactivityPrompt?
    /// Remaining seconds before auto-end once confirmation is active.
    private(set) var cardioAutoEndCountdown: Int?
    /// Recommendation only; keeps recording until the user explicitly ends the workout.
    private(set) var isStairExitPromptPresented = false

    // MARK: - Live Metrics

    private(set) var heartRate: Double = 0
    private(set) var activeCalories: Double = 0

    /// Total distance in meters (cardio mode only).
    private(set) var distance: Double = 0
    private var lastAnnouncedKilometer = 0
    private(set) var latestDistanceMilestone: Int?

    /// Total steps in current session.
    private(set) var steps: Double = 0

    /// Current pace in seconds per kilometer (cardio mode only).
    private(set) var currentPace: Double = 0

    /// Estimated max HR based on HealthKit dateOfBirth (220-age formula).
    /// Defaults to 190 (HeartRateZoneCalculator.defaultMaxHR) when age is unavailable.
    private(set) var estimatedMaxHR: Double = HeartRateZoneCalculator.defaultMaxHR

    /// HealthKit's live zone group can contain a personalized number of zones.
    private(set) var liveZoneDistribution: WorkoutZoneDistribution?
    private(set) var liveZoneIndex: Int?

    var displayedZoneIndex: Int? {
        guard let liveZoneDistribution else { return currentZone?.rawValue }
        return WatchZoneDisplay.number(for: liveZoneIndex, in: liveZoneDistribution)
    }
    var displayedZoneCount: Int { liveZoneDistribution?.zones.count ?? HeartRateZone.Zone.allCases.count }

    /// Current heart rate zone based on live HR and estimated maxHR.
    var currentZone: HeartRateZone.Zone? {
        guard heartRate > 0, estimatedMaxHR > 0 else { return nil }
        return HeartRateZone.Zone.zone(forFraction: heartRate / estimatedMaxHR)
    }

    /// Current HR as a fraction of estimated maxHR (0.0–1.0, clamped).
    var hrFraction: Double {
        guard estimatedMaxHR > 0 else { return 0 }
        return min(heartRate / estimatedMaxHR, 1.0)
    }

    /// Total flights (floors) climbed (stair climber mode only).
    private(set) var floorsClimbed: Double = 0
    /// Current machine level for non-distance machine cardio sessions.
    private(set) var currentMachineLevel: Int?
    /// Time-weighted average machine level across the active cardio session.
    private(set) var averageMachineLevel: Double?
    /// Highest machine level reached during the session.
    private(set) var maxMachineLevel: Int?
    private(set) var machineLevelChanges: [CardioMachineLevelChange] = []

    /// Running samples for average HR calculation.
    private var heartRateSamples: [Double] = []
    private var machineLevelWeightedSeconds: TimeInterval = 0
    private var machineLevelWeightedSum: Double = 0
    private var lastMachineLevelSampleDate: Date?
    private var inactivityMonitorTask: Task<Void, Never>?
    private var lastMotionDate: Date?
    private var lastInteractionDate: Date?
    private var lastObservedDistance: Double = 0
    private var lastObservedSteps: Double = 0
    private var lastObservedFloorsClimbed: Double = 0
    private var lastObservedActiveCalories: Double = 0
    private var autoEndDeadline: Date?
    @ObservationIgnored private var stairExitMonitor: StairMachineExitMonitor?
    private(set) var hasDismissedStairExitPrompt = false

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

    var supportsMachineLevel: Bool {
        cardioSecondaryUnit?.supportsMachineLevel == true
    }

    var formattedCurrentMachineLevel: String {
        currentMachineLevel.map { $0.formattedWithSeparator } ?? "--"
    }

    var formattedAverageMachineLevel: String {
        guard let averageMachineLevel, averageMachineLevel.isFinite else { return "--" }
        return averageMachineLevel.formatted(.number.precision(.fractionLength(1)))
    }

    var formattedMaxMachineLevel: String {
        maxMachineLevel.map { $0.formattedWithSeparator } ?? "--"
    }

    var cardioMachineAutoIntensityRaw: Double? {
        cardioSecondaryUnit?.normalizedMachineLevelScore(averageMachineLevel)
    }

    /// Active elapsed time using an explicit clock value.
    func activeElapsedTime(at now: Date) -> TimeInterval {
        WorkoutElapsedTime.activeElapsedTime(
            startDate: startDate,
            pausedDuration: pausedDuration,
            pauseStart: pauseStart,
            isPaused: isPaused,
            now: now,
            completedDuration: completedDuration
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

    func plannedSetCount(for exerciseIndex: Int) -> Int? {
        guard let entries = templateSnapshot?.entries, entries.indices.contains(exerciseIndex) else { return nil }
        return entries[exerciseIndex].defaultSets + (extraSetsPerExercise[exerciseIndex] ?? 0)
    }

    var isLastSet: Bool {
        return currentSetIndex >= effectiveTotalSets - 1
    }

    var isLastExercise: Bool {
        guard let snapshot = templateSnapshot else { return true }
        return currentExerciseIndex >= snapshot.entries.count - 1
    }

    /// Indices of exercises explicitly skipped by the user.
    private(set) var skippedExerciseIndices: Set<Int> = []

    /// Whether all remaining exercises are either completed (have sets) or skipped.
    var isAllExercisesDone: Bool {
        guard let snapshot = templateSnapshot else { return true }
        // Check if any exercise from the start is still pending
        for i in 0..<snapshot.entries.count {
            let hasCompletedSets = i < completedSetsData.count && !completedSetsData[i].isEmpty
            if !hasCompletedSets && !skippedExerciseIndices.contains(i) {
                return false
            }
        }
        return true
    }

    /// Last completed set for the current exercise (for weight/reps pre-fill).
    var lastCompletedSetForCurrentExercise: CompletedSetData? {
        guard currentExerciseIndex < completedSetsData.count else { return nil }
        return completedSetsData[currentExerciseIndex].last
    }

    /// Planned set data restored from Quick Start procedure snapshot for the current set.
    var currentPlannedSetForCurrentExercise: WatchProcedureSetSnapshot? {
        guard let snapshot = templateSnapshot,
              currentExerciseIndex < snapshot.entries.count else { return nil }
        let exerciseID = snapshot.entries[currentExerciseIndex].exerciseDefinitionID
        return snapshot.procedureSetsByExerciseID?[exerciseID]?
            .first { $0.setNumber == currentSetIndex + 1 }
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
            HKQuantityType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKCharacteristicType(.dateOfBirth),
            HKQuantityType(.flightsClimbed),
            HKSeriesType.workoutRoute()
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

    // MARK: - Max HR Estimation

    /// Fetches the user's estimated max HR from HealthKit dateOfBirth (220-age formula).
    /// Falls back to `HeartRateZoneCalculator.defaultMaxHR` (190) on any failure.
    private func fetchEstimatedMaxHR() {
        do {
            let dob = try healthStore.dateOfBirthComponents()
            if let year = dob.year {
                let age = Calendar.current.component(.year, from: Date()) - year
                estimatedMaxHR = HeartRateZoneCalculator.estimateMaxHR(age: age)
                Self.logger.info("Estimated maxHR=\(self.estimatedMaxHR) from age=\(age)")
            }
        } catch {
            Self.logger.info("dateOfBirth unavailable, using default maxHR=\(self.estimatedMaxHR)")
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
    func startCardioSession(
        activityType: WorkoutActivityType,
        isOutdoor: Bool,
        secondaryUnit: CardioSecondaryUnit? = nil,
        initialLevel: Int? = nil
    ) async throws {
        let previousMode = workoutMode
        let previousCardioSecondaryUnit = cardioSecondaryUnit
        let previousDistance = distance
        let previousSteps = steps
        let previousPace = currentPace
        let previousFloors = floorsClimbed
        let previousTemplateSnapshot = templateSnapshot
        let previousExerciseIndex = currentExerciseIndex
        let previousSetIndex = currentSetIndex
        let previousCompletedSets = completedSetsData
        let previousExtraSets = extraSetsPerExercise
        let previousMachineLevelChanges = machineLevelChanges

        self.workoutMode = .cardio(activityType: activityType, isOutdoor: isOutdoor)
        self.cardioSecondaryUnit = secondaryUnit
        self.distance = 0
        self.lastAnnouncedKilometer = 0
        self.latestDistanceMilestone = nil
        self.steps = 0
        self.currentPace = 0
        self.floorsClimbed = 0
        self.currentMachineLevel = nil
        self.averageMachineLevel = nil
        self.maxMachineLevel = nil
        self.machineLevelChanges = []
        self.machineLevelWeightedSeconds = 0
        self.machineLevelWeightedSum = 0
        self.lastMachineLevelSampleDate = nil
        // templateSnapshot is nil for cardio — no set/exercise tracking needed
        self.templateSnapshot = nil
        self.completedSetsData = []
        self.extraSetsPerExercise = [:]

        fetchEstimatedMaxHR()

        let config = HKWorkoutConfiguration()
        config.activityType = activityType.hkWorkoutActivityType
        config.locationType = isOutdoor ? .outdoor : .indoor

        do {
            try await startHKSession(config: config, templateName: activityType.typeName)
            clearMachineLevelRecoveryHistory()
            if let initialLevel {
                setMachineLevel(initialLevel)
            }
        } catch {
            // Restore state on failure to prevent inconsistent workoutMode
            workoutMode = previousMode
            cardioSecondaryUnit = previousCardioSecondaryUnit
            distance = previousDistance
            steps = previousSteps
            currentPace = previousPace
            floorsClimbed = previousFloors
            templateSnapshot = previousTemplateSnapshot
            currentExerciseIndex = previousExerciseIndex
            currentSetIndex = previousSetIndex
            completedSetsData = previousCompletedSets
            extraSetsPerExercise = previousExtraSets
            machineLevelChanges = previousMachineLevelChanges
            throw error
        }
    }

    /// Common strength HK session setup.
    private func startStrengthSession(with snapshot: WorkoutSessionTemplate) async throws {
        self.workoutMode = .strength
        self.cardioSecondaryUnit = nil
        var resolvedSnapshot = snapshot
        resolvedSnapshot.entries = snapshot.entries.map {
            resolvedWatchEntry($0, exercise: WatchConnectivityManager.shared.exerciseInfo(for: $0.exerciseDefinitionID))
        }
        self.templateSnapshot = resolvedSnapshot
        self.currentExerciseIndex = 0
        self.currentSetIndex = 0
        self.completedSetsData = Array(repeating: [], count: snapshot.entries.count)
        self.extraSetsPerExercise = [:]
        self.distance = 0
        self.lastAnnouncedKilometer = 0
        self.latestDistanceMilestone = nil
        self.steps = 0
        self.currentPace = 0
        self.currentMachineLevel = nil
        self.averageMachineLevel = nil
        self.maxMachineLevel = nil
        self.machineLevelChanges = []
        self.machineLevelWeightedSeconds = 0
        self.machineLevelWeightedSum = 0
        self.lastMachineLevelSampleDate = nil

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        try await startHKSession(config: config, templateName: snapshot.name)
    }

    /// Common HK session setup shared by strength and cardio flows.
    private func startHKSession(config: HKWorkoutConfiguration, templateName: String) async throws {
        routeRecorder?.cancel()
        routeRecorder = nil
        capturedRoute = []
        runningVoiceFeedback.stop()
        runningVoiceFeedback.resetProgress()
        stopMirrorTransport()
        mirrorWorkoutName = templateName
        self.heartRateSamples = []
        self.liveZoneDistribution = nil
        self.liveZoneIndex = nil
        self.steps = 0
        self.isSessionEnded = false
        self.isFinalizingWorkout = false
        self.finalizationTimeoutTask?.cancel()
        self.finalizationTimeoutTask = nil
        self.didNotifyWorkoutEnded = false
        self.healthKitWorkoutUUID = nil
        self.isRecoveredSession = false
        self.isSimulatedSessionActive = false
        self.completedDuration = nil
        self.pausedDuration = 0
        self.pauseStart = nil
        self.hasDismissedStairExitPrompt = false
        self.resetCardioInactivityTracking(clearInteractionTimestamp: true)

        if Self.isSimulatorRuntime {
            startSimulatedSession(templateName: templateName)
            startInactivityMonitoringIfNeeded()
            runningVoiceFeedback.resetProgress(
                distanceMeters: distance,
                activeElapsed: activeElapsedTime(at: Date())
            )
            announceRunning(.started)
            return
        }

        let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let newBuilder = newSession.associatedWorkoutBuilder()

        session = newSession
        builder = newBuilder

        newSession.delegate = self
        newBuilder.delegate = self
        let dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )
        // stepCount and flightsClimbed are not auto-collected by HKLiveWorkoutDataSource;
        // enable explicitly so workoutBuilder(_:didCollectDataOf:) receives updates.
        dataSource.enableCollection(for: HKQuantityType(.stepCount), predicate: nil)
        dataSource.enableCollection(for: HKQuantityType(.flightsClimbed), predicate: nil)
        if case .cardio(let activityType, _) = workoutMode, activityType.isStairBased {
            dataSource.enableCollection(for: HKQuantityType(.distanceWalkingRunning), predicate: nil)
        }
        newBuilder.dataSource = dataSource

        do {
            newSession.prepare()
            let now = Date()
            startDate = now
            lastMachineLevelSampleDate = supportsMachineLevel ? now : nil
            newSession.startActivity(with: now)
            try await runWithTimeout(
                seconds: 10,
                timeoutError: WorkoutStartupError.beginCollectionTimedOut
            ) {
                try await newBuilder.beginCollection(at: now)
            }

            startRouteCaptureIfNeeded(at: Date())
            // Persist recovery state
            persistRecoveryState()

            // Notify iPhone via WatchConnectivity
            WatchConnectivityManager.shared.sendWorkoutStarted(templateName: templateName)
            startInactivityMonitoringIfNeeded()
            startMirrorTransport(for: newSession)
            announceRunning(.started)
        } catch {
            routeRecorder?.cancel()
            routeRecorder = nil
            capturedRoute = []
            Self.logger.error("Failed to start HK session: \(String(describing: error), privacy: .public)")
            newSession.end()
            session = nil
            builder = nil
            isPaused = false
            isSessionEnded = false
            startDate = nil
            isSimulatedSessionActive = false
            completedDuration = nil
            pausedDuration = 0
            pauseStart = nil
            stopInactivityMonitoring()
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
        lastMachineLevelSampleDate = supportsMachineLevel ? startDate : nil
        completedDuration = nil
        pausedDuration = 0
        pauseStart = nil
        resetCardioInactivityTracking(clearInteractionTimestamp: true)
#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-watch-six-zones"),
           case .cardio = workoutMode {
            liveZoneDistribution = WorkoutZoneDistribution(
                source: .system,
                bins: (0..<6).map { index in
                    .init(
                        index: index,
                        minimumBPM: index == 0 ? nil : Double(100 + index * 20),
                        maximumBPM: index == 5 ? nil : Double(120 + index * 20),
                        durationSeconds: 30
                    )
                }
            )
            liveZoneIndex = ProcessInfo.processInfo.arguments.contains("--ui-watch-first-zone") ? 0 : 2
            heartRate = 135
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-watch-kilometer-milestone"),
           case .cardio = workoutMode {
            distance = 990
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-watch-running-distance"),
           case .cardio(.running, _) = workoutMode {
            startDate = Date().addingTimeInterval(-1_170)
            distance = 3_240
            lastAnnouncedKilometer = 3
            currentPace = 1_170 / 3.24
            heartRate = 148
        }
#endif
        persistRecoveryState()
        WatchConnectivityManager.shared.sendWorkoutStarted(templateName: templateName)
    }

    func setMachineLevel(_ level: Int) {
        guard isActive, let cardioSecondaryUnit,
              let normalized = cardioSecondaryUnit.normalizedMachineLevel(level),
              normalized != currentMachineLevel else { return }
        let now = Date()
        captureMachineLevelSegment(until: now)
        if let change = CardioMachineLevelChange(elapsedSeconds: activeElapsedTime(at: now), level: normalized) {
            machineLevelChanges.append(change)
            appendMachineLevelRecoveryHistory(change)
        }
        currentMachineLevel = normalized
        maxMachineLevel = max(maxMachineLevel ?? normalized, normalized)
        persistRecoveryState()
    }

    func adjustMachineLevel(by delta: Int) {
        guard let range = cardioSecondaryUnit?.machineLevelRange else { return }
        let baseline = currentMachineLevel ?? range.lowerBound
        setMachineLevel(baseline + delta)
    }

    func pause() {
        if let session {
            beginPause(at: Date())
            enqueueMirrorSnapshot()
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
            enqueueMirrorSnapshot()
            session.resume()
            return
        }
        if isSimulatedSessionActive {
            endPause(at: Date())
        }
    }

    func end() {
        guard !isSessionEnded, session != nil || isSimulatedSessionActive else { return }
        // Ending the HK session removes background workout audio runtime.
        // Manual foreground completion can finish its cue on the summary screen.
        if WKApplication.shared().applicationState == .active {
            announceRunning(.ended)
        } else {
            runningVoiceFeedback.stop()
        }
        let endDate = Date()
        stopRouteCapture()
        completedDuration = activeElapsedTime(at: endDate)
        captureMachineLevelSegment(until: endDate)
        endPause(at: endDate, announcesResume: false)

        if isSimulatedSessionActive {
            isPaused = false
            isSessionEnded = true
            isFinalizingWorkout = false
            isSimulatedSessionActive = false
            notifyWorkoutEndedIfNeeded()
            stopInactivityMonitoring()
            return
        }

        guard session != nil else { return }

        // Transition UI immediately even when simulator callbacks are delayed.
        isSessionEnded = true
        isFinalizingWorkout = session != nil
        session?.end()
        notifyWorkoutEndedIfNeeded()

        if isFinalizingWorkout {
            startFinalizationTimeoutWatchdog()
        }
        stopInactivityMonitoring()
    }

    /// User explicitly keeps cardio workout running from inactivity recommendation.
    func keepCardioWorkoutRunning() {
        lastInteractionDate = Date()
        clearInactivityPrompt()
    }

    /// Pause workout directly from inactivity recommendation.
    func pauseFromCardioInactivityPrompt() {
        keepCardioWorkoutRunning()
        pause()
    }

    func keepStairWorkoutRunning() {
        hasDismissedStairExitPrompt = true
        stopStairExitMonitoring()
        persistRecoveryState()
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

    func completeSet(weight: Double?, reps: Int?, duration: TimeInterval? = nil, rpe: Double? = nil) {
        // Validate input ranges before recording (mirrors iPhone validation rules)
        let inputType = TemplateExerciseProfile.normalizedInputTypeRaw(currentEntry?.inputTypeRaw)
            .flatMap(ExerciseInputType.init(rawValue:)) ?? .setsRepsWeight
        let validatedWeight = weight.flatMap { WatchSetInputPolicy.completedWeight($0, inputType: inputType) }
        let validatedReps: Int? = reps.flatMap { (0...1000).contains($0) ? $0 : nil }
        let validatedDuration: TimeInterval? = duration.flatMap { (0...7200).contains($0) ? $0 : nil }
        let validatedRPE: Double? = rpe.flatMap { RPELevel.validate($0) }

        let planned = currentPlannedSetForCurrentExercise
        let plannedReps = planned?.plannedReps ?? planned?.reps ?? currentEntry?.defaultReps
        let data = CompletedSetData(
            setNumber: currentSetIndex + 1,
            weight: validatedWeight,
            reps: validatedReps,
            duration: validatedDuration,
            completedAt: Date(),
            rpe: validatedRPE,
            plannedReps: plannedReps,
            rpeSourceRaw: validatedRPE == nil ? nil : "user",
            setTypeRaw: planned?.setTypeRaw ?? SetType.working.rawValue
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

    /// Record auto-estimated or user-adjusted RPE on the last completed set.
    func recordSetRPE(_ rpe: Double, source: String) {
        guard currentExerciseIndex < completedSetsData.count else { return }
        let lastIdx = completedSetsData[currentExerciseIndex].count - 1
        guard lastIdx >= 0 else { return }
        let validated = RPELevel.validate(rpe)
        completedSetsData[currentExerciseIndex][lastIdx].rpe = validated
        completedSetsData[currentExerciseIndex][lastIdx].rpeSourceRaw = validated == nil ? nil : source
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
        // Skip-aware: find next non-skipped, non-completed exercise
        if let nextIdx = nextPendingExerciseIndex(after: currentExerciseIndex) {
            currentExerciseIndex = nextIdx
            currentSetIndex = 0
        } else if currentExerciseIndex < snapshot.entries.count - 1 {
            // Fallback: simple increment (all remaining are skipped/completed)
            currentExerciseIndex += 1
            currentSetIndex = 0
        }
        enqueueMirrorSnapshot()
    }

    /// Skip the current exercise and advance to the next non-skipped pending exercise.
    /// Returns `true` if there is a next exercise to propose, `false` if all are done.
    @discardableResult
    func skipExercise() -> Bool {
        guard templateSnapshot != nil else { return false }
        skippedExerciseIndices.insert(currentExerciseIndex)

        if let nextIdx = nextPendingExerciseIndex(after: currentExerciseIndex) {
            currentExerciseIndex = nextIdx
            currentSetIndex = 0
            enqueueMirrorSnapshot()
            return true
        }
        return false
    }

    /// Find the next exercise index after `after` that is neither skipped nor completed.
    private func nextPendingExerciseIndex(after index: Int) -> Int? {
        guard let snapshot = templateSnapshot else { return nil }
        for i in (index + 1)..<snapshot.entries.count {
            let hasCompletedSets = i < completedSetsData.count && !completedSetsData[i].isEmpty
            if !hasCompletedSets && !skippedExerciseIndices.contains(i) {
                return i
            }
        }
        return nil
    }

    // MARK: - Exercise Reordering

    enum MoveDirection {
        case up, down
    }

    /// Whether the exercise at the given index can be moved in the specified direction.
    func canMoveExercise(at index: Int, direction: MoveDirection) -> Bool {
        guard let snapshot = templateSnapshot else { return false }
        let count = snapshot.entries.count
        guard index >= 0, index < count else { return false }
        // Cannot move exercises that have completed sets
        if index < completedSetsData.count, !completedSetsData[index].isEmpty { return false }
        switch direction {
        case .up:
            guard index > 0 else { return false }
            guard index - 1 < completedSetsData.count else { return true }
            return completedSetsData[index - 1].isEmpty
        case .down:
            guard index < count - 1 else { return false }
            guard index + 1 < completedSetsData.count else { return true }
            return completedSetsData[index + 1].isEmpty
        }
    }

    /// Whether there are at least 2 non-completed exercises that can be reordered.
    var canReorderExercises: Bool {
        guard let snapshot = templateSnapshot else { return false }
        var nonCompleted = 0
        for i in 0..<snapshot.entries.count {
            if i >= completedSetsData.count || completedSetsData[i].isEmpty {
                nonCompleted += 1
                if nonCompleted >= 2 { return true }
            }
        }
        return false
    }

    /// Move the exercise at the given index up or down by one position.
    /// Keeps `completedSetsData`, `extraSetsPerExercise`, and `currentExerciseIndex` in sync.
    func moveExercise(at index: Int, direction: MoveDirection) {
        guard canMoveExercise(at: index, direction: direction),
              var snapshot = templateSnapshot,
              currentExerciseIndex < snapshot.entries.count else { return }

        let targetIndex: Int
        switch direction {
        case .up: targetIndex = index - 1
        case .down: targetIndex = index + 1
        }

        // Track current exercise identity before swap
        let currentEntryID = snapshot.entries[currentExerciseIndex].id

        // Swap entries in local copy (publish to observers only after all arrays are synced)
        snapshot.entries.swapAt(index, targetIndex)

        // Pad completedSetsData to match entries count before swap
        let entryCount = snapshot.entries.count
        while completedSetsData.count < entryCount {
            completedSetsData.append([])
        }
        completedSetsData.swapAt(index, targetIndex)

        // Remap extraSetsPerExercise keys (swap values at index <-> targetIndex)
        let extraAtIndex = extraSetsPerExercise[index]
        let extraAtTarget = extraSetsPerExercise[targetIndex]
        extraSetsPerExercise.removeValue(forKey: index)
        extraSetsPerExercise.removeValue(forKey: targetIndex)
        if let v = extraAtIndex { extraSetsPerExercise[targetIndex] = v }
        if let v = extraAtTarget { extraSetsPerExercise[index] = v }

        // Remap skippedExerciseIndices (swap membership at index <-> targetIndex)
        let indexWasSkipped = skippedExerciseIndices.contains(index)
        let targetWasSkipped = skippedExerciseIndices.contains(targetIndex)
        skippedExerciseIndices.remove(index)
        skippedExerciseIndices.remove(targetIndex)
        if indexWasSkipped { skippedExerciseIndices.insert(targetIndex) }
        if targetWasSkipped { skippedExerciseIndices.insert(index) }

        // Restore currentExerciseIndex to follow the same exercise
        if let newIndex = snapshot.entries.firstIndex(where: { $0.id == currentEntryID }) {
            currentExerciseIndex = newIndex
        }

        // Publish snapshot after all companion arrays are synced
        templateSnapshot = snapshot
        persistRecoveryState()
    }

    /// Applies a SwiftUI reorder using entry identities, keeping every index-based companion value attached.
    func reorderExercises(moving sourceIDs: [UUID], before destinationID: UUID?) {
        guard var snapshot = templateSnapshot,
              snapshot.entries.indices.contains(currentExerciseIndex) else { return }
        let originalEntries = snapshot.entries
        let originalIDs = originalEntries.map(\.id)
        let completedIndices = Set(originalEntries.indices.filter {
            $0 < completedSetsData.count && !completedSetsData[$0].isEmpty
        })
        guard let orderedIDs = Self.reorderedExerciseIDs(
            originalIDs, completedIndices: completedIndices,
            moving: sourceIDs, before: destinationID
        ) else { return }

        let oldIndexByID = Dictionary(uniqueKeysWithValues: originalIDs.enumerated().map { ($0.element, $0.offset) })
        let currentID = originalIDs[currentExerciseIndex]
        let completed = originalEntries.indices.map { $0 < completedSetsData.count ? completedSetsData[$0] : [] }
        let extras = extraSetsPerExercise
        let skipped = skippedExerciseIndices
        snapshot.entries = orderedIDs.compactMap { id in oldIndexByID[id].map { originalEntries[$0] } }
        completedSetsData = orderedIDs.compactMap { id in oldIndexByID[id].map { completed[$0] } }
        extraSetsPerExercise = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().compactMap { newIndex, id in
            guard let oldIndex = oldIndexByID[id], let count = extras[oldIndex] else { return nil }
            return (newIndex, count)
        })
        skippedExerciseIndices = Set(orderedIDs.enumerated().compactMap { newIndex, id in
            guard let oldIndex = oldIndexByID[id], skipped.contains(oldIndex) else { return nil }
            return newIndex
        })
        currentExerciseIndex = orderedIDs.firstIndex(of: currentID) ?? currentExerciseIndex
        templateSnapshot = snapshot
        persistRecoveryState()
    }

    /// Rejects any drag that would move a completed exercise or shift its fixed position.
    static func reorderedExerciseIDs(
        _ ids: [UUID], completedIndices: Set<Int>, moving sourceIDs: [UUID], before destinationID: UUID?
    ) -> [UUID]? {
        let sourceSet = Set(sourceIDs)
        guard !sourceSet.isEmpty, sourceSet.count == sourceIDs.count,
              Set(ids).count == ids.count, sourceSet.isSubset(of: Set(ids)),
              completedIndices.allSatisfy({ ids.indices.contains($0) && !sourceSet.contains(ids[$0]) }) else { return nil }
        if let destinationID, (!ids.contains(destinationID) || sourceSet.contains(destinationID)) { return nil }

        let movingIDs = ids.filter { sourceSet.contains($0) }
        var remaining = ids.filter { !sourceSet.contains($0) }
        let insertionIndex = destinationID.flatMap { remaining.firstIndex(of: $0) } ?? remaining.endIndex
        remaining.insert(contentsOf: movingIDs, at: insertionIndex)
        guard completedIndices.allSatisfy({ remaining[$0] == ids[$0] }), remaining != ids else { return nil }
        return remaining
    }

    func reset() {
        routeRecorder?.cancel()
        routeRecorder = nil
        capturedRoute = []
        runningVoiceFeedback.stop()
        runningVoiceFeedback.resetProgress()
        stopMirrorTransport()
        stopInactivityMonitoring()
        finalizationTimeoutTask?.cancel()
        finalizationTimeoutTask = nil
        session = nil
        builder = nil
        templateSnapshot = nil
        workoutMode = .strength
        cardioSecondaryUnit = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        completedSetsData = []
        extraSetsPerExercise = [:]
        skippedExerciseIndices = []
        heartRate = 0
        activeCalories = 0
        distance = 0
        lastAnnouncedKilometer = 0
        latestDistanceMilestone = nil
        steps = 0
        currentPace = 0
        estimatedMaxHR = HeartRateZoneCalculator.defaultMaxHR
        heartRateSamples = []
        currentMachineLevel = nil
        averageMachineLevel = nil
        maxMachineLevel = nil
        machineLevelChanges = []
        machineLevelWeightedSeconds = 0
        machineLevelWeightedSum = 0
        lastMachineLevelSampleDate = nil
        isPaused = false
        isSessionEnded = false
        isFinalizingWorkout = false
        isSimulatedSessionActive = false
        didNotifyWorkoutEnded = false
        isRecoveredSession = false
        startDate = nil
        healthKitWorkoutUUID = nil
        completedDuration = nil
        pausedDuration = 0
        pauseStart = nil
        cardioInactivityPrompt = nil
        cardioAutoEndCountdown = nil
        autoEndDeadline = nil
        hasDismissedStairExitPrompt = false
        lastMotionDate = nil
        lastInteractionDate = nil
        lastObservedDistance = 0
        lastObservedSteps = 0
        lastObservedFloorsClimbed = 0
        lastObservedActiveCalories = 0
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
            restoreRecoveredSessionState(recovered.state, at: Date())

            // Restore distance from builder statistics if cardio session
            if isCardioMode {
                restoreDistanceFromBuilder(recoveredBuilder)
                lastAnnouncedKilometer = Int(distance / 1000)
            }

            // If strength mode but template couldn't be restored, mark as recovered session
            if !isCardioMode, templateSnapshot == nil {
                isRecoveredSession = true
            }
            if case .cardio(let activityType, _) = workoutMode {
                mirrorWorkoutName = activityType.typeName
            } else {
                mirrorWorkoutName = templateSnapshot?.name ?? String(localized: "Workout")
            }
            isSessionEnded = recovered.state == .ended
            isPaused = recovered.state == .paused
            startDate = startDate ?? recovered.startDate ?? recoveredBuilder.startDate
            if let startDate {
                let now = Date()
                let elapsed = recoveredBuilder.elapsedTime(at: now)
                if elapsed.isFinite, elapsed >= 0 {
                    pausedDuration = max(0, now.timeIntervalSince(startDate) - elapsed)
                    pauseStart = isPaused ? now : nil
                }
            }
            runningVoiceFeedback.resetProgress(
                distanceMeters: distance,
                activeElapsed: activeElapsedTime(at: Date())
            )
            if isPaused { runningVoiceFeedback.suspendProgress() }
            if isSessionEnded {
                notifyWorkoutEndedIfNeeded()
            } else {
                startRouteCaptureIfNeeded(at: Date())
                if isPaused { routeRecorder?.pause(at: Date()) }
                startInactivityMonitoringIfNeeded()
                startMirrorTransport(for: recovered)
            }
        } catch {
            // No active session to recover
        }
    }

    /// Restores distance and floors metrics from builder statistics after crash recovery.
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

        // Restore flights climbed for stair workouts
        if let stats = builder.statistics(for: HKQuantityType(.flightsClimbed)),
           let floors = stats.sumQuantity()?.doubleValue(for: .count()),
           floors > 0, floors.isFinite, floors < 10_000 {
            floorsClimbed = floors
        }

        // Restore step count
        if let stats = builder.statistics(for: HKQuantityType(.stepCount)),
           let totalSteps = stats.sumQuantity()?.doubleValue(for: .count()),
           totalSteps > 0, totalSteps < 200_000 {
            steps = totalSteps
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
            workoutMode: workoutMode,
            cardioSecondaryUnit: cardioSecondaryUnit,
            currentMachineLevel: currentMachineLevel,
            averageMachineLevel: averageMachineLevel,
            maxMachineLevel: maxMachineLevel,
            // History is append-only on disk so the state snapshot stays small.
            machineLevelChanges: nil,
            machineLevelEventCount: machineLevelChanges.count,
            pausedDuration: pausedDuration,
            pauseStart: pauseStart,
            machineLevelWeightedSeconds: machineLevelWeightedSeconds,
            machineLevelWeightedSum: machineLevelWeightedSum,
            lastMachineLevelSampleDate: lastMachineLevelSampleDate,
            hasDismissedStairExitPrompt: hasDismissedStairExitPrompt
        )
        guard let data = try? JSONEncoder().encode(state),
              data.count < 64_000 else { return }
        UserDefaults.standard.set(data, forKey: Self.recoveryKey)
    }

    func restoreRecoveredSessionState(_ recoveredState: HKWorkoutSessionState, at now: Date) {
        restoreRecoveryState()
        switch recoveredState {
        case .paused:
            // Older snapshots did not store pause accounting. Start tracking at recovery.
            if pauseStart == nil { beginPause(at: now) }
            isPaused = true
        case .running:
            if pauseStart != nil { endPause(at: now) }
            isPaused = false
        default:
            break
        }
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
        hasDismissedStairExitPrompt = state.hasDismissedStairExitPrompt ?? false
        cardioSecondaryUnit = state.cardioSecondaryUnit
        currentMachineLevel = state.currentMachineLevel
        averageMachineLevel = state.averageMachineLevel
        maxMachineLevel = state.maxMachineLevel
        let diskChanges = loadMachineLevelRecoveryHistory(for: state.startDate)
        machineLevelChanges = diskChanges ?? state.machineLevelChanges ?? []
        if let diskChanges,
           diskChanges.count > (state.machineLevelEventCount ?? 0),
           let latestLevel = diskChanges.last?.level {
            currentMachineLevel = latestLevel
        }
        pausedDuration = state.pausedDuration ?? 0
        pauseStart = state.pauseStart
        isPaused = pauseStart != nil
        machineLevelWeightedSeconds = state.machineLevelWeightedSeconds
        machineLevelWeightedSum = state.machineLevelWeightedSum
        lastMachineLevelSampleDate = state.lastMachineLevelSampleDate
        isRecoveredSession = false
    }

    private func clearRecoveryState() {
        UserDefaults.standard.removeObject(forKey: Self.recoveryKey)
        clearMachineLevelRecoveryHistory()
    }

    static var recoveryHistoryURL: URL {
        URL.applicationSupportDirectory.appending(path: "machine-level-recovery.jsonl")
    }

    private func appendMachineLevelRecoveryHistory(_ change: CardioMachineLevelChange) {
        guard let startDate else { return }
        do {
            let url = Self.recoveryHistoryURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            var line = try JSONEncoder().encode(MachineLevelRecoveryEntry(startDate: startDate, change: change))
            line.append(0x0A)
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forUpdating: url)
                defer { try? handle.close() }
                let end = try handle.seekToEnd()
                if end > 0 {
                    try handle.seek(toOffset: end - 1)
                    if try handle.read(upToCount: 1) != Data([0x0A]) {
                        let existing = try Data(contentsOf: url)
                        let completeLength = existing.lastIndex(of: 0x0A).map { $0 + 1 } ?? 0
                        try handle.truncate(atOffset: UInt64(completeLength))
                    }
                }
                _ = try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } else {
                try line.write(to: url, options: .atomic)
            }
        } catch {
            Self.logger.error("Could not persist machine level change: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadMachineLevelRecoveryHistory(for startDate: Date?) -> [CardioMachineLevelChange]? {
        guard let startDate,
              let data = try? Data(contentsOf: Self.recoveryHistoryURL) else { return nil }
        let decoder = JSONDecoder()
        let changes: [CardioMachineLevelChange] = data.split(separator: 0x0A).compactMap { line in
            guard let entry = try? decoder.decode(MachineLevelRecoveryEntry.self, from: Data(line)),
                  entry.startDate == startDate else { return nil }
            return CardioMachineLevelChange(
                elapsedSeconds: entry.change.elapsedSeconds, level: entry.change.level
            )
        }
        return changes.isEmpty ? nil : changes
    }

    private func clearMachineLevelRecoveryHistory() {
        try? FileManager.default.removeItem(at: Self.recoveryHistoryURL)
    }

    // MARK: - Workout Mirroring

    private func startMirrorTransport(for workoutSession: HKWorkoutSession, isRetry: Bool = false) {
        stopMirrorTransport(resetRetryPolicy: !isRetry)
        let generation = mirrorGeneration
        mirrorStartTask = Task { @MainActor [weak self] in
            do {
                try await workoutSession.startMirroringToCompanionDevice()
                guard let self,
                      self.mirrorGeneration == generation,
                      self.session === workoutSession,
                      !self.isSessionEnded else { return }
                self.mirrorStartTask = nil
                self.mirroredSession = workoutSession
                self.enqueueMirrorSnapshot()
                self.mirrorIntervalTask = Task { @MainActor [weak self] in
                    while !Task.isCancelled {
                        do {
                            try await Task.sleep(for: .seconds(5))
                        } catch {
                            return
                        }
                        guard let self,
                              self.mirrorGeneration == generation,
                              self.session === workoutSession,
                              !self.isSessionEnded else { return }
                        self.enqueueMirrorSnapshot()
                    }
                }
            } catch {
                guard let self, self.mirrorGeneration == generation else { return }
                self.mirrorStartTask = nil
                Self.logger.error("Workout mirroring failed: \(String(describing: error), privacy: .private)")
                self.handleMirrorFailure(for: workoutSession)
            }
        }
    }

    private func stopMirrorTransport(resetRetryPolicy: Bool = true) {
        mirrorGeneration = UUID()
        mirrorStartTask?.cancel()
        mirrorStartTask = nil
        mirrorIntervalTask?.cancel()
        mirrorIntervalTask = nil
        mirrorSendTask?.cancel()
        mirrorSendTask = nil
        mirrorRetryTask?.cancel()
        mirrorRetryTask = nil
        mirroredSession = nil
        pendingMirrorSnapshot = nil
        if resetRetryPolicy {
            mirrorRetryPolicy.reset()
        }
    }

    private func handleMirrorFailure(for workoutSession: HKWorkoutSession) {
        guard session === workoutSession, !isSessionEnded else { return }
        // A send failure and disconnect callback can describe the same outage.
        guard !mirrorRetryPolicy.isRetryScheduled else { return }
        let shouldRetry = mirrorRetryPolicy.recordFailure()
        stopMirrorTransport(resetRetryPolicy: false)
        if shouldRetry {
            scheduleMirrorRetry(for: workoutSession)
        }
    }

    private func scheduleMirrorRetry(for workoutSession: HKWorkoutSession) {
        guard mirrorRetryTask == nil else { return }
        let generation = mirrorGeneration
        mirrorRetryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            guard let self,
                  self.mirrorGeneration == generation,
                  self.session === workoutSession,
                  !self.isSessionEnded else { return }
            self.mirrorRetryTask = nil
            guard self.mirrorRetryPolicy.beginRetry() else { return }
            self.startMirrorTransport(for: workoutSession, isRetry: true)
        }
    }

    func phoneDidReconnect() {
        guard let workoutSession = session,
              !isSessionEnded,
              mirrorRetryPolicy.recordReconnect() else { return }
        scheduleMirrorRetry(for: workoutSession)
    }

    private func workoutSnapshot(at now: Date = Date()) -> WatchWorkoutSnapshot? {
        guard let startDate else { return nil }
        let activityType: WorkoutActivityType
        if let session {
            // Recovery metadata can be absent; the live HealthKit session remains authoritative.
            activityType = WorkoutActivityType(healthKit: session.workoutConfiguration.activityType)
        } else {
            activityType = switch workoutMode {
            case .cardio(let activityType, _): activityType
            case .strength: .traditionalStrengthTraining
            }
        }
        let snapshot = WatchWorkoutSnapshot(
            startedAt: startDate,
            updatedAt: now,
            exerciseName: currentEntry?.exerciseName ?? mirrorWorkoutName,
            elapsedSeconds: activeElapsedTime(at: now),
            phase: isSessionEnded ? .ended : (isPaused ? .paused : .running),
            heartRate: (20...250).contains(heartRate) ? heartRate : nil,
            activeCalories: activeCalories,
            distanceMeters: isCardioMode ? distance : 0,
            exerciseIconName: activityType.iconName
        )
        return snapshot.isValid ? snapshot : nil
    }

    private func enqueueMirrorSnapshot() {
        guard let mirroredSession, let snapshot = workoutSnapshot() else { return }
        pendingMirrorSnapshot = snapshot
        guard mirrorSendTask == nil else { return }
        let generation = mirrorGeneration
        mirrorSendTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while let snapshot = self.pendingMirrorSnapshot {
                self.pendingMirrorSnapshot = nil
                do {
                    let data = try JSONEncoder().encode(snapshot)
                    try await mirroredSession.sendToRemoteWorkoutSession(data: data)
                } catch {
                    guard self.mirrorGeneration == generation else { return }
                    Self.logger.error("Workout mirror send failed: \(String(describing: error), privacy: .private)")
                    self.handleMirrorFailure(for: mirroredSession)
                    return
                }
                guard self.mirrorGeneration == generation,
                      self.session === mirroredSession else { return }
                self.mirrorRetryPolicy.recordSuccess()
            }
            self.mirrorSendTask = nil
        }
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

    private func startRouteCaptureIfNeeded(at date: Date) {
        guard !Self.isSimulatorRuntime, !isSessionEnded, !isPaused,
              routeRecorder == nil, session?.state == .running,
              WorkoutRouteRecorder.shouldRecord(mode: workoutMode) else { return }
        let recorder = WorkoutRouteRecorder()
        routeRecorder = recorder
        recorder.start(at: date)
    }

    private func stopRouteCapture() {
        guard let routeRecorder else { return }
        capturedRoute = routeRecorder.stop()
        self.routeRecorder = nil
    }

    private func enqueueRouteSave(_ points: [WorkoutRoutePoint], workout: HKWorkout) {
        guard !points.isEmpty, routeSaveJobs[workout.uuid] == nil else { return }
        // Bound concurrent optional enrichment even if workouts are ended in rapid succession.
        if routeSaveJobs.count >= 2, let existingID = routeSaveJobs.keys.sorted(by: { $0.uuidString < $1.uuidString }).first {
            routeSaveJobs[existingID]?.cancel()
        }
        let id = workout.uuid
        let job = WorkoutRouteSaveJob(
            points: points,
            writer: HealthKitWorkoutRouteSegmentWriter(store: healthStore, workout: workout)
        ) { [weak self] in self?.routeSaveJobs[id] = nil }
        routeSaveJobs[id] = job
        job.start()
    }

    private func notifyWorkoutEndedIfNeeded() {
        guard !didNotifyWorkoutEnded else { return }
        didNotifyWorkoutEnded = true
        WatchConnectivityManager.shared.sendWorkoutEnded(snapshot: workoutSnapshot())
        // HealthKit stops mirroring when the session ends; WC carries the durable terminal state.
        stopMirrorTransport()
    }

    private func startFinalizationTimeoutWatchdog(timeout seconds: TimeInterval = 6) {
        finalizationTimeoutTask?.cancel()
        let finalizingSession = session
        finalizationTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            guard self.session === finalizingSession, self.isFinalizingWorkout else { return }
            Self.logger.error("Workout finalization timed out; allowing summary completion")
            self.isFinalizingWorkout = false
        }
    }

    private func beginPause(at date: Date) {
        routeRecorder?.pause(at: date)
        guard pauseStart == nil else {
            isPaused = true
            return
        }
        captureMachineLevelSegment(until: date)
        lastMachineLevelSampleDate = nil
        pauseStart = date
        isPaused = true
        runningVoiceFeedback.suspendProgress()
        announceRunning(.paused)
        clearInactivityPrompt()
        stopStairExitMonitoring()
        persistRecoveryState()
    }

    private func endPause(at date: Date, announcesResume: Bool = true) {
        let wasPaused = pauseStart != nil
        if let pauseStart {
            let delta = date.timeIntervalSince(pauseStart)
            if delta > 0 {
                pausedDuration += delta
            }
            self.pauseStart = nil
        }
        if supportsMachineLevel {
            lastMachineLevelSampleDate = date
        }
        isPaused = false
        if wasPaused, announcesResume, !isSessionEnded {
            routeRecorder?.resume(at: date)
            startRouteCaptureIfNeeded(at: date)
            startStairExitMonitoringIfNeeded()
            runningVoiceFeedback.resumeProgress(
                distanceMeters: distance,
                activeElapsed: activeElapsedTime(at: date)
            )
            announceRunning(.resumed)
        }
        lastInteractionDate = date
        persistRecoveryState()
    }

    private func captureMachineLevelSegment(until date: Date) {
        guard supportsMachineLevel else { return }
        guard let lastMachineLevelSampleDate else {
            self.lastMachineLevelSampleDate = date
            return
        }
        let delta = max(date.timeIntervalSince(lastMachineLevelSampleDate), 0)
        guard delta > 0 else { return }

        if let currentMachineLevel {
            machineLevelWeightedSeconds += delta
            machineLevelWeightedSum += Double(currentMachineLevel) * delta
            averageMachineLevel = machineLevelWeightedSum / machineLevelWeightedSeconds
        }

        self.lastMachineLevelSampleDate = date
    }

    private func startInactivityMonitoringIfNeeded() {
        stopInactivityMonitoring()
        guard isCardioMode else { return }

        resetCardioInactivityTracking(clearInteractionTimestamp: true)
        startStairExitMonitoringIfNeeded()

#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-watch-stair-exit-regression"),
           case .cardio(let activityType, _) = workoutMode,
           activityType.isStairBased {
            simulateFormerStairExitTimeline()
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-watch-stair-gps-exit"),
           case .cardio(let activityType, _) = workoutMode,
           activityType.isStairBased {
            simulateStairGPSExitTimeline()
        }
#endif

        inactivityMonitorTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                self.evaluateCardioInactivity(at: Date())
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

#if DEBUG && targetEnvironment(simulator)
    private func simulateFormerStairExitTimeline() {
        let start = Date().addingTimeInterval(-120)
        startDate = start
        for (seconds, sampledDistance, sampledSteps) in [
            (90.0, 0.0, 120.0),
            (100.0, 7.0, 125.0),
            (119.0, 29.0, 141.0),
            (120.0, 32.0, 142.0)
        ] {
            distance = sampledDistance
            steps = sampledSteps
            evaluateCardioInactivity(at: start.addingTimeInterval(seconds))
        }
    }

    private func simulateStairGPSExitTimeline() {
        let start = Date().addingTimeInterval(-240)
        startDate = start
        var detector = StairMachineExitDetector(startedAt: start)
        for seconds in stride(from: 120.0, through: 240.0, by: 10.0) {
            steps = seconds - 120
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37 + (seconds - 120) * 0.000012, longitude: 127),
                altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
                timestamp: start.addingTimeInterval(seconds)
            )
            if detector.observe(location: location, steps: steps, now: location.timestamp) {
                presentStairExitPrompt()
            }
        }
    }
#endif

    private func stopInactivityMonitoring() {
        inactivityMonitorTask?.cancel()
        inactivityMonitorTask = nil
        clearInactivityPrompt()
        stopStairExitMonitoring()
    }

    private func startStairExitMonitoringIfNeeded() {
        guard isActive, !isPaused, !hasDismissedStairExitPrompt,
              stairExitMonitor == nil,
              case .cardio(let activityType, _) = workoutMode,
              activityType.isStairBased,
              !Self.isSimulatorRuntime else { return }
        let monitor = StairMachineExitMonitor(
            startedAt: startDate ?? Date(),
            steps: { [weak self] in self?.steps ?? 0 },
            onExit: { [weak self] in self?.presentStairExitPrompt() }
        )
        stairExitMonitor = monitor
        monitor.start()
    }

    private func stopStairExitMonitoring() {
        stairExitMonitor?.stop()
        stairExitMonitor = nil
        isStairExitPromptPresented = false
    }

    private func presentStairExitPrompt() {
        guard isActive, !isPaused, !hasDismissedStairExitPrompt,
              !isStairExitPromptPresented,
              case .cardio(let activityType, _) = workoutMode,
              activityType.isStairBased else { return }
        isStairExitPromptPresented = true
        // Active HKWorkoutSession permits haptics even when the view is not foreground.
        WKInterfaceDevice.current().play(.notification)
    }

    private func resetCardioInactivityTracking(clearInteractionTimestamp: Bool) {
        lastMotionDate = Date()
        if clearInteractionTimestamp {
            lastInteractionDate = Date()
        }
        updateObservedCardioMetricsBaseline()
        clearInactivityPrompt()
    }

    private func clearInactivityPrompt() {
        cardioInactivityPrompt = nil
        cardioAutoEndCountdown = nil
        autoEndDeadline = nil
    }

    private func currentObservedCardioMetrics() -> CardioInactivityObservedMetrics {
        CardioInactivityObservedMetrics(
            distance: distance,
            steps: steps,
            floorsClimbed: floorsClimbed,
            activeCalories: activeCalories
        )
    }

    private func updateObservedCardioMetricsBaseline() {
        let currentMetrics = currentObservedCardioMetrics()
        lastObservedDistance = currentMetrics.distance
        lastObservedSteps = currentMetrics.steps
        lastObservedFloorsClimbed = currentMetrics.floorsClimbed
        lastObservedActiveCalories = currentMetrics.activeCalories
    }

    private func evaluateCardioInactivity(at now: Date) {
        guard isCardioMode, isActive, !isSessionEnded, !isPaused else {
            clearInactivityPrompt()
            return
        }

        if ProcessInfo.processInfo.arguments.contains("--uitesting-watch") {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--ui-watch-cardio-soft-nudge") {
                cardioInactivityPrompt = .softNudge
                return
            }
            if arguments.contains("--ui-watch-cardio-auto-end") {
                cardioInactivityPrompt = .confirmation
                cardioAutoEndCountdown = 30
                return
            }
        }

        let previousMetrics = CardioInactivityObservedMetrics(
            distance: lastObservedDistance,
            steps: lastObservedSteps,
            floorsClimbed: lastObservedFloorsClimbed,
            activeCalories: lastObservedActiveCalories
        )
        let currentMetrics = currentObservedCardioMetrics()

        if CardioInactivityActivitySignal.hasProgress(
            workoutMode: workoutMode,
            supportsMachineLevel: supportsMachineLevel,
            previous: previousMetrics,
            current: currentMetrics
        ) {
            lastMotionDate = now
            updateObservedCardioMetricsBaseline()
            clearInactivityPrompt()
            return
        }

        let referenceDate = max(lastMotionDate ?? now, lastInteractionDate ?? now)
        let evaluation = CardioInactivityPolicy.evaluate(
            workoutMode: workoutMode,
            inactivityDuration: now.timeIntervalSince(referenceDate),
            autoEndDeadline: autoEndDeadline,
            now: now
        )

        switch evaluation {
        case .none:
            clearInactivityPrompt()
        case .softNudge:
            cardioInactivityPrompt = .softNudge
            cardioAutoEndCountdown = nil
        case .confirmation(let deadline):
            autoEndDeadline = deadline
            cardioInactivityPrompt = .confirmation
            cardioAutoEndCountdown = max(Int(ceil(deadline.timeIntervalSince(now))), 0)
        case .autoEnd:
            clearInactivityPrompt()
            end()
        }
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
                startRouteCaptureIfNeeded(at: date)
                enqueueMirrorSnapshot()
            case .paused:
                beginPause(at: date)
                enqueueMirrorSnapshot()
            case .ended:
                stopRouteCapture()
                let endedRoute = capturedRoute
                capturedRoute = []
                if completedDuration == nil { completedDuration = activeElapsedTime(at: date) }
                endPause(at: date, announcesResume: false)
                isSessionEnded = true
                stopInactivityMonitoring()
                isFinalizingWorkout = true
                notifyWorkoutEndedIfNeeded()
                startFinalizationTimeoutWatchdog()
                let endedBuilder = builder
                let endedWorkoutMode = workoutMode
                defer {
                    if session === workoutSession {
                        finalizationTimeoutTask?.cancel()
                        finalizationTimeoutTask = nil
                        isFinalizingWorkout = false
                    }
                }
                do {
                    try await endedBuilder?.endCollection(at: date)
                    if endedWorkoutMode == .strength {
                        // Strength template: discard the merged workout so individual
                        // per-exercise HKWorkouts can be created in SessionSummaryView.
                        endedBuilder?.discardWorkout()
                        // Log after discard completes to confirm success.
                        Self.logger.info("Discarded merged builder workout for strength session")
                    } else {
                        // Cardio: keep the single live-builder workout as-is.
                        let workout = try await endedBuilder?.finishWorkout()
                        if session === workoutSession,
                           let workoutID = workout?.uuid.uuidString, !workoutID.isEmpty {
                            healthKitWorkoutUUID = workoutID
                        }
                        if let workout, !endedRoute.isEmpty {
                            enqueueRouteSave(endedRoute, workout: workout)
                        }
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
            routeRecorder?.cancel()
            routeRecorder = nil
            capturedRoute = []
            Self.logger.error("Workout session failed: \(error.localizedDescription, privacy: .public)")
            runningVoiceFeedback.stop()
            finalizationTimeoutTask?.cancel()
            finalizationTimeoutTask = nil
            isFinalizingWorkout = false
            stopMirrorTransport()
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didDisconnectFromRemoteDeviceWithError error: Error?
    ) {
        Task { @MainActor in
            guard let currentSession = session,
                  workoutSession === currentSession,
                  mirroredSession === workoutSession else { return }
            if let error {
                Self.logger.error("Workout mirror disconnected: \(String(describing: error), privacy: .private)")
            }
            handleMirrorFailure(for: workoutSession)
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
        didUpdateWorkoutZone update: HKLiveWorkoutZoneUpdate
    ) {
        // Extract Sendable values before crossing to MainActor. The update and
        // builder objects themselves must stay on the delegate callback thread.
        let callbackBuilderID = ObjectIdentifier(workoutBuilder)
        let distribution = update.zoneGroup.map(WorkoutZoneDistribution.init(group:))
        let zoneIndex = update.currentZoneDuration?.zone.index
        Task { @MainActor in
            guard !isSessionEnded,
                  let builder,
                  ObjectIdentifier(builder) == callbackBuilderID else { return }
            if let distribution { liveZoneDistribution = distribution }
            liveZoneIndex = zoneIndex
        }
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let callbackBuilderID = ObjectIdentifier(workoutBuilder)
        // Extract primitive values on the delegate callback thread (before actor hop)
        // to avoid cross-actor access of non-Sendable HKLiveWorkoutBuilder.
        var heartRateValue: Double?
        var caloriesValue: Double?
        var distanceValue: Double?
        var floorsValue: Double?
        var stepValue: Double?

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

            case HKQuantityType(.flightsClimbed):
                let floors = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                if floors > 0, floors.isFinite, floors < 10_000 {
                    floorsValue = floors
                }

            case HKQuantityType(.stepCount):
                let totalSteps = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                if totalSteps > 0, totalSteps < 200_000 {
                    stepValue = totalSteps
                }

            default:
                break
            }
        }

        // Dispatch only primitive values to MainActor
        Task { @MainActor in
            guard !isSessionEnded,
                  let builder,
                  ObjectIdentifier(builder) == callbackBuilderID else { return }
            if let bpm = heartRateValue {
                heartRate = bpm
                heartRateSamples.append(bpm)
            }
            if let kcal = caloriesValue {
                activeCalories = kcal
            }
            if let meters = distanceValue {
                updateDistance(meters)
            }
            if let floors = floorsValue {
                floorsClimbed = floors
            }
            if let totalSteps = stepValue {
                steps = totalSteps
            }

            evaluateCardioInactivity(at: Date())
        }
    }

    private func updateDistance(_ meters: Double) {
        guard meters.isFinite, (0..<500_000).contains(meters) else { return }
        distance = meters
        updatePace()
        guard !isSessionEnded,
              case .cardio(let activityType, _) = workoutMode,
              activityType.isDistanceBased else { return }
        if isPaused {
            lastAnnouncedKilometer = max(lastAnnouncedKilometer, Int(meters / 1000))
            return
        }
        if activityType == .running {
            runningVoiceFeedback.processProgress(
                distanceMeters: meters,
                activeElapsed: activeElapsedTime(at: Date())
            )
        }
        guard
              let milestone = CardioDistanceMilestone.reached(
                distanceMeters: meters,
                after: lastAnnouncedKilometer
              ) else { return }
        lastAnnouncedKilometer = milestone
        latestDistanceMilestone = milestone
        WKInterfaceDevice.current().play(.notification)
    }

#if DEBUG && targetEnvironment(simulator)
    func simulateKilometerMilestoneIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--ui-watch-kilometer-milestone"),
              isCardioMode, distance < 1_000 else { return }
        updateDistance(1_010)
    }
#endif

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

enum CardioInactivityPrompt: Equatable {
    case softNudge
    case confirmation
}

enum CardioInactivityPolicy {
    static let softNudgeAfter: TimeInterval = 75
    static let confirmationAfter: TimeInterval = 120
    static let countdownDuration: TimeInterval = 10

    static func evaluate(
        workoutMode: WorkoutMode,
        inactivityDuration: TimeInterval,
        autoEndDeadline: Date?,
        now: Date
    ) -> CardioInactivityEvaluation {
        // Wrist motion and live metrics cannot reliably show whether a stair machine is still running.
        if case .cardio(let activityType, _) = workoutMode, activityType.isStairBased {
            return .none
        }

        if let autoEndDeadline {
            return now >= autoEndDeadline
                ? .autoEnd
                : .confirmation(deadline: autoEndDeadline)
        }

        guard inactivityDuration >= softNudgeAfter else {
            return .none
        }

        if inactivityDuration >= confirmationAfter {
            return .confirmation(deadline: now.addingTimeInterval(countdownDuration))
        }

        return .softNudge
    }
}

enum CardioInactivityEvaluation: Equatable {
    case none
    case softNudge
    case confirmation(deadline: Date)
    case autoEnd
}

struct CardioInactivityObservedMetrics: Equatable {
    let distance: Double
    let steps: Double
    let floorsClimbed: Double
    let activeCalories: Double
}

enum CardioInactivityActivitySignal {
    static func hasProgress(
        workoutMode: WorkoutMode,
        supportsMachineLevel: Bool,
        previous: CardioInactivityObservedMetrics,
        current: CardioInactivityObservedMetrics
    ) -> Bool {
        if current.distance > previous.distance || current.steps > previous.steps {
            return true
        }

        if case .cardio(let activityType, _) = workoutMode,
           activityType.isStairBased,
           current.floorsClimbed > previous.floorsClimbed {
            return true
        }

        if supportsMachineLevel, current.activeCalories > previous.activeCalories {
            return true
        }

        return false
    }
}

enum CardioDistanceMilestone {
    static func reached(distanceMeters: Double, after lastAnnouncedKilometer: Int) -> Int? {
        guard distanceMeters.isFinite, (0..<500_000).contains(distanceMeters),
              lastAnnouncedKilometer >= 0 else { return nil }
        let kilometer = Int(distanceMeters / 1000)
        return kilometer > lastAnnouncedKilometer ? kilometer : nil
    }
}

enum WatchZoneDisplay {
    static func number(for rawIndex: Int?, in distribution: WorkoutZoneDistribution) -> Int? {
        guard let rawIndex,
              let position = distribution.zones.firstIndex(where: { $0.index == rawIndex }) else { return nil }
        return position + 1
    }
}

enum WorkoutElapsedTime {
    static func activeElapsedTime(
        startDate: Date?,
        pausedDuration: TimeInterval,
        pauseStart: Date?,
        isPaused: Bool,
        now: Date,
        completedDuration: TimeInterval? = nil
    ) -> TimeInterval {
        if let completedDuration { return completedDuration }
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
    /// Duration in seconds for durationIntensity exercises (e.g. plank).
    let duration: TimeInterval?
    let completedAt: Date
    /// Rest timer total (including +30s adjustments) used after this set, in seconds.
    var restDuration: TimeInterval?
    /// Per-set RPE (Rate of Perceived Exertion), Modified Borg scale 6.0-10.0.
    var rpe: Double?
    var plannedReps: Int? = nil
    var rpeSourceRaw: String? = nil
    var setTypeRaw: String? = nil
}

/// Plain struct snapshot of WorkoutTemplate data.
/// Avoids holding a SwiftData @Model reference in the singleton (M6).
struct WorkoutSessionTemplate: Codable, Sendable {
    let name: String
    var entries: [TemplateEntry]
    let procedureSetsByExerciseID: [String: [WatchProcedureSetSnapshot]]?

    init(
        name: String,
        entries: [TemplateEntry],
        procedureSetsByExerciseID: [String: [WatchProcedureSetSnapshot]]? = nil
    ) {
        self.name = name
        self.entries = entries
        self.procedureSetsByExerciseID = procedureSetsByExerciseID
    }
}

/// Persisted state for crash recovery (C4).
private struct WorkoutRecoveryState: Codable {
    let template: WorkoutSessionTemplate?
    let exerciseIndex: Int
    let setIndex: Int
    let completedSets: [[CompletedSetData]]
    let startDate: Date?
    let workoutMode: WorkoutMode?
    let cardioSecondaryUnit: CardioSecondaryUnit?
    let currentMachineLevel: Int?
    let averageMachineLevel: Double?
    let maxMachineLevel: Int?
    let machineLevelChanges: [CardioMachineLevelChange]?
    let machineLevelEventCount: Int?
    let pausedDuration: TimeInterval?
    let pauseStart: Date?
    let machineLevelWeightedSeconds: TimeInterval
    let machineLevelWeightedSum: Double
    let lastMachineLevelSampleDate: Date?
    let hasDismissedStairExitPrompt: Bool?
}

private struct MachineLevelRecoveryEntry: Codable {
    let startDate: Date
    let change: CardioMachineLevelChange
}

enum WorkoutStartupError: LocalizedError {
    case authorizationTimedOut
    case authorizationNotGranted
    case beginCollectionTimedOut

    var errorDescription: String? {
        String(localized: "Could not start workout. Please try again.")
    }
}
