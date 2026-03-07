import Foundation
import Observation

/// Data produced by a completed cardio session — passed from ViewModel to View for persistence.
struct CardioSessionRecord: Sendable {
    let exerciseID: String
    let exerciseName: String
    let category: ExerciseCategory
    let duration: TimeInterval
    let distanceKm: Double?
    let stepCount: Int?
    let averagePaceSecondsPerKm: Double?
    let averageCadenceStepsPerMinute: Double?
    let elevationGainMeters: Double?
    let floorsAscended: Double?
    let cardioMachineLevelAverage: Double?
    let cardioMachineLevelMax: Int?
    let estimatedCalories: Double
    let metValue: Double
    let autoIntensityRaw: Double?
    let startDate: Date
    /// VO2 Max (cardio fitness) from HealthKit at workout time (ml/kg/min).
    let cardioFitnessVO2Max: Double?
}

/// Manages state for an iOS cardio live tracking session.
/// Tracks elapsed time, distance, pace, and motion metrics.
@Observable
@MainActor
final class CardioSessionViewModel {
    // MARK: - Configuration

    let exercise: ExerciseDefinition
    let activityType: WorkoutActivityType
    let isOutdoor: Bool

    // MARK: - Session State

    enum SessionState: Sendable {
        case idle
        case running
        case paused
        case finished
    }

    private(set) var state: SessionState = .idle
    private(set) var startDate: Date?
    private(set) var elapsedSeconds: TimeInterval = 0
    private(set) var totalDistanceMeters: Double = 0
    private(set) var totalElevationGainMeters: Double = 0
    private(set) var stepCount: Int = 0
    private(set) var cadenceStepsPerMinute: Double = 0
    private(set) var floorsAscended: Double = 0
    private(set) var currentMachineLevel: Int?
    private(set) var averageMachineLevel: Double?
    private(set) var maxMachineLevel: Int?
    private(set) var currentPaceSecondsPerKm: Double = 0
    private(set) var averagePaceSecondsPerKm: Double = 0
    private(set) var estimatedCalories: Double = 0
    private(set) var heartRate: Double = 0
    private(set) var walkingStepCount: Double = 0
    /// Latest VO2 Max (cardio fitness) fetched from HealthKit (ml/kg/min).
    private(set) var cardioFitnessVO2Max: Double?
    var errorMessage: String?

    /// Formatted elapsed time "M:SS" or "H:MM:SS".
    var formattedElapsed: String {
        let total = Int(elapsedSeconds)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    /// Distance in kilometers.
    var distanceKm: Double { totalDistanceMeters / 1000.0 }

    /// Formatted distance "0.00".
    var formattedDistance: String {
        String(format: "%.2f", distanceKm)
    }

    /// Current pace in "M:SS /km" format. Returns "--:--" when no valid pace.
    var formattedPace: String {
        Self.formatPace(currentPaceSecondsPerKm)
    }

    /// Formatted steps.
    var formattedStepCount: String {
        stepCount > 0 ? stepCount.formattedWithSeparator : "--"
    }

    /// Formatted cadence "###" or "--".
    var formattedCadence: String {
        guard cadenceStepsPerMinute > 0, cadenceStepsPerMinute.isFinite else { return "--" }
        return Int(cadenceStepsPerMinute).formattedWithSeparator
    }

    /// Formatted elevation gain in meters "###" or "--".
    var formattedElevationGain: String {
        guard totalElevationGainMeters > 0, totalElevationGainMeters.isFinite else { return "--" }
        return Int(totalElevationGainMeters).formattedWithSeparator
    }

    var cardioUnit: CardioSecondaryUnit {
        exercise.cardioSecondaryUnit ?? .km
    }

    /// Whether distance/pace should be shown for this activity type.
    var showsDistance: Bool {
        exercise.cardioSecondaryUnit?.usesDistanceField ?? activityType.isDistanceBased
    }

    var supportsMachineLevel: Bool {
        cardioUnit.supportsMachineLevel
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

    // MARK: - Dependencies

    private let locationService: LocationTrackingServiceProtocol?
    private let motionService: MotionTrackingServiceProtocol
    private let calorieService: CalorieEstimating
    private let stepsService: StepsQuerying?
    private let vitalsService: VitalsQuerying?
    private var timerTask: Task<Void, Never>?
    private var pausedAccumulated: TimeInterval = 0
    private var lastResumeDate: Date?
    private var baselineDaySteps: Double?
    private var lastStepRefreshAt: Date?
    private var machineLevelWeightedSeconds: TimeInterval = 0
    private var machineLevelWeightedSum: Double = 0
    private var machineAdjustedMETSeconds: Double = 0
    private var lastMachineLevelSampleDate: Date?

    private var usesGPSDistance: Bool {
        isOutdoor && locationService != nil
    }

    // MARK: - Init

    init(
        exercise: ExerciseDefinition,
        activityType: WorkoutActivityType,
        isOutdoor: Bool,
        locationService: LocationTrackingServiceProtocol? = nil,
        motionService: MotionTrackingServiceProtocol? = nil,
        calorieService: CalorieEstimating = CalorieEstimationService(),
        stepsService: StepsQuerying? = nil,
        vitalsService: VitalsQuerying? = nil
    ) {
        self.exercise = exercise
        self.activityType = activityType
        self.isOutdoor = isOutdoor
        self.locationService = isOutdoor ? (locationService ?? LocationTrackingService()) : nil
        self.motionService = motionService ?? MotionTrackingService()
        self.calorieService = calorieService
        self.stepsService = activityType == .walking
            ? (stepsService ?? StepsQueryService(manager: .shared))
            : nil
        self.vitalsService = vitalsService ?? VitalsQueryService(manager: .shared)
    }

    // MARK: - Session Lifecycle

    func start() {
        guard state == .idle else { return }

        startDate = Date()
        lastResumeDate = startDate
        pausedAccumulated = 0
        resetLiveMetrics()
        lastMachineLevelSampleDate = startDate
        state = .running
        baselineDaySteps = nil
        lastStepRefreshAt = nil
        startTimer()

        if let startDate {
            Task {
                do {
                    try await motionService.startTracking(from: startDate)
                } catch {
                    errorMessage = String(localized: "Could not start motion tracking. Steps may be incomplete.")
                    AppLogger.healthKit.error("[CardioSession] Motion start failed: \(error)")
                }
            }
        }

        if activityType == .walking {
            Task { @MainActor [weak self] in
                await self?.establishWalkingStepBaseline()
            }
        }

        if isOutdoor, let locationService {
            Task {
                do {
                    try await locationService.startTracking()
                } catch {
                    errorMessage = String(localized: "Could not start GPS tracking. Distance will use step-based fallback.")
                    AppLogger.healthKit.error("[CardioSession] Location start failed: \(error)")
                }
            }
        }
    }

    func pause() {
        guard state == .running else { return }
        captureMachineLevelSegment(until: Date())
        if let resume = lastResumeDate {
            pausedAccumulated += Date().timeIntervalSince(resume)
        }
        lastMachineLevelSampleDate = nil
        lastResumeDate = nil
        state = .paused
        timerTask?.cancel()
    }

    func resume() {
        guard state == .paused else { return }
        lastResumeDate = Date()
        lastMachineLevelSampleDate = lastResumeDate
        state = .running
        startTimer()
    }

    func end() async {
        guard state == .running || state == .paused else { return }
        let endDate = Date()

        // Cancel timer FIRST to prevent race condition
        timerTask?.cancel()
        timerTask = nil

        // Compute final elapsed time
        captureMachineLevelSegment(until: endDate)
        if state == .running, let resume = lastResumeDate {
            pausedAccumulated += endDate.timeIntervalSince(resume)
            lastResumeDate = nil
        }
        lastMachineLevelSampleDate = nil
        elapsedSeconds = pausedAccumulated

        // Get final distance/elevation from GPS
        if let locationService {
            totalDistanceMeters = Swift.max(0, await locationService.stopTracking())
            totalElevationGainMeters = Swift.max(0, locationService.totalElevationGainMeters)
        }

        // Get final motion snapshot
        let motionSnapshot = await motionService.stopTracking()
        applyMotionSnapshot(motionSnapshot, isFinal: true)

        updateCurrentPace()
        updateAveragePace()
        updateCalories(at: endDate)
        if activityType == .walking {
            await refreshWalkingSteps(force: true)
        }
        await fetchCardioFitness()
        state = .finished
    }

    func setMachineLevel(_ level: Int) {
        guard supportsMachineLevel, let normalized = cardioUnit.normalizedMachineLevel(level) else { return }
        let now = Date()
        captureMachineLevelSegment(until: now)
        currentMachineLevel = normalized
        maxMachineLevel = max(maxMachineLevel ?? normalized, normalized)
        updateCalories(at: now)
    }

    func adjustMachineLevel(by delta: Int) {
        guard supportsMachineLevel, let range = cardioUnit.machineLevelRange else { return }
        let baseline = currentMachineLevel ?? range.lowerBound
        setMachineLevel(baseline + delta)
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                let now = Date()
                self.updateElapsed(at: now)

                if let locationService = self.locationService {
                    self.totalDistanceMeters = locationService.totalDistanceMeters
                    self.totalElevationGainMeters = locationService.totalElevationGainMeters
                }

                self.applyMotionSnapshot(self.motionService.latestSnapshot, isFinal: false)
                self.updateCurrentPace()
                self.updateAveragePace()
                self.updateCalories(at: now)
                if self.activityType == .walking {
                    Task { @MainActor [weak self] in
                        await self?.refreshWalkingSteps()
                    }
                }
            }
        }
    }

    private func updateElapsed(at now: Date) {
        guard let resume = lastResumeDate else { return }
        elapsedSeconds = pausedAccumulated + now.timeIntervalSince(resume)
    }

    private func updateCurrentPace() {
        guard elapsedSeconds > 0 else {
            currentPaceSecondsPerKm = 0
            return
        }

        let km = totalDistanceMeters / 1000.0
        if km > 0.05 {
            let pace = elapsedSeconds / km
            if Self.isValidPace(pace) {
                currentPaceSecondsPerKm = pace
                return
            }
        }

        if !Self.isValidPace(currentPaceSecondsPerKm) {
            currentPaceSecondsPerKm = 0
        }
    }

    private func updateAveragePace() {
        let km = totalDistanceMeters / 1000.0
        guard elapsedSeconds > 0, km > 0 else {
            if !Self.isValidPace(averagePaceSecondsPerKm) {
                averagePaceSecondsPerKm = 0
            }
            return
        }

        let pace = elapsedSeconds / km
        if Self.isValidPace(pace) {
            averagePaceSecondsPerKm = pace
        }
    }

    private func applyMotionSnapshot(_ snapshot: MotionTrackingSnapshot, isFinal: Bool) {
        if snapshot.stepCount > 0 {
            stepCount = max(stepCount, snapshot.stepCount)
        }

        if let cadence = snapshot.cadenceStepsPerMinute,
           cadence > 0, cadence.isFinite, cadence < 300 {
            cadenceStepsPerMinute = cadence
        }

        if let floors = snapshot.floorsAscended,
           floors >= 0, floors.isFinite, floors < 20_000 {
            floorsAscended = floors
        }

        if let motionDistance = snapshot.distanceMeters,
           motionDistance > 0, motionDistance.isFinite,
           totalDistanceMeters <= 0 {
            totalDistanceMeters = motionDistance
        }

        if totalElevationGainMeters <= 0, floorsAscended > 0 {
            // Approximation fallback when absolute elevation data is unavailable.
            totalElevationGainMeters = floorsAscended * 3.0
        }

        if !usesGPSDistance || totalDistanceMeters <= 0 {
            if let pace = snapshot.currentPaceSecondsPerKm, Self.isValidPace(pace) {
                currentPaceSecondsPerKm = pace
            }
        }

        if isFinal,
           averagePaceSecondsPerKm <= 0,
           let averagePace = snapshot.averagePaceSecondsPerKm,
           Self.isValidPace(averagePace) {
            averagePaceSecondsPerKm = averagePace
        }
    }

    private func updateCalories(at now: Date = Date()) {
        guard elapsedSeconds > 0 else { return }
        let metValue: Double = {
            guard supportsMachineLevel else { return exercise.metValue }
            captureMachineLevelSegment(until: now)
            let safeElapsed = max(elapsedSeconds, 1)
            return max(machineAdjustedMETSeconds / safeElapsed, exercise.metValue * 0.5)
        }()
        let calories = calorieService.estimate(
            metValue: metValue,
            bodyWeightKg: CalorieEstimationService.defaultBodyWeightKg,
            durationSeconds: elapsedSeconds,
            restSeconds: 0
        )
        estimatedCalories = calories ?? 0
    }

    private func fetchCardioFitness() async {
        guard let vitalsService else { return }
        do {
            let sample = try await vitalsService.fetchLatestVO2Max(withinDays: 30)
            if let sample {
                cardioFitnessVO2Max = sample.value
            }
        } catch {
            // VO2Max is optional — keep nil on failure.
            AppLogger.healthKit.warning("[CardioSession] VO2Max fetch failed: \(error)")
        }
    }

    private func resetLiveMetrics() {
        elapsedSeconds = 0
        totalDistanceMeters = 0
        totalElevationGainMeters = 0
        stepCount = 0
        cadenceStepsPerMinute = 0
        floorsAscended = 0
        currentMachineLevel = nil
        averageMachineLevel = nil
        maxMachineLevel = nil
        currentPaceSecondsPerKm = 0
        averagePaceSecondsPerKm = 0
        estimatedCalories = 0
        heartRate = 0
        walkingStepCount = 0
        cardioFitnessVO2Max = nil
        machineLevelWeightedSeconds = 0
        machineLevelWeightedSum = 0
        machineAdjustedMETSeconds = 0
        lastMachineLevelSampleDate = nil
    }

    private func establishWalkingStepBaseline() async {
        guard let stepsService else { return }
        do {
            let todaySteps = try await stepsService.fetchSteps(for: Date()) ?? 0
            baselineDaySteps = max(todaySteps, 0)
            walkingStepCount = 0
        } catch {
            // HealthKit steps are optional during session; keep silent fallback.
            baselineDaySteps = nil
            walkingStepCount = 0
        }
        await refreshWalkingSteps(force: true)
    }

    private func refreshWalkingSteps(force: Bool = false) async {
        guard let stepsService else { return }
        if !force,
           let lastStepRefreshAt,
           Date().timeIntervalSince(lastStepRefreshAt) < 8 {
            return
        }

        do {
            let todaySteps = try await stepsService.fetchSteps(for: Date()) ?? 0
            let baseline = baselineDaySteps ?? todaySteps
            baselineDaySteps = baseline
            let delta = max(0, todaySteps - baseline)
            if delta.isFinite, delta < 200_000 {
                walkingStepCount = delta
            }
            lastStepRefreshAt = Date()
        } catch {
            // Keep previous value on transient query errors.
        }
    }

    private func captureMachineLevelSegment(until date: Date) {
        guard supportsMachineLevel else { return }
        guard let lastMachineLevelSampleDate else {
            self.lastMachineLevelSampleDate = date
            return
        }
        let delta = max(date.timeIntervalSince(lastMachineLevelSampleDate), 0)
        guard delta > 0 else { return }

        let segmentMET = exercise.metValue * cardioUnit.metMultiplier(forMachineLevel: currentMachineLevel)
        machineAdjustedMETSeconds += segmentMET * delta

        if let currentMachineLevel {
            machineLevelWeightedSeconds += delta
            machineLevelWeightedSum += Double(currentMachineLevel) * delta
            averageMachineLevel = machineLevelWeightedSum / machineLevelWeightedSeconds
        }

        self.lastMachineLevelSampleDate = date
    }

    // MARK: - Record Creation

    /// Creates a record from the completed cardio session.
    func createExerciseRecord() -> CardioSessionRecord? {
        guard state == .finished, let startDate, elapsedSeconds > 0 else { return nil }

        let distance: Double? = totalDistanceMeters > 0 ? totalDistanceMeters / 1000.0 : nil
        let safePace = Self.isValidPace(averagePaceSecondsPerKm) ? averagePaceSecondsPerKm : nil
        let safeCadence = (cadenceStepsPerMinute > 0 && cadenceStepsPerMinute.isFinite && cadenceStepsPerMinute < 300)
            ? cadenceStepsPerMinute
            : nil
        let safeElevation = (totalElevationGainMeters > 0 && totalElevationGainMeters.isFinite && totalElevationGainMeters < 20_000)
            ? totalElevationGainMeters
            : nil
        let safeFloors = (floorsAscended > 0 && floorsAscended.isFinite && floorsAscended < 20_000)
            ? floorsAscended
            : nil
        let safeAverageMachineLevel = averageMachineLevel.flatMap {
            ($0.isFinite && $0 > 0) ? $0 : nil
        }
        let safeMaxMachineLevel = maxMachineLevel.flatMap { cardioUnit.normalizedMachineLevel($0) }
        let referenceMachineLevel = safeAverageMachineLevel.map { Int($0.rounded()) }
            ?? safeMaxMachineLevel
            ?? currentMachineLevel
        let combinedSteps = max(stepCount, Int(walkingStepCount.rounded()))

        return CardioSessionRecord(
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            category: exercise.category,
            duration: elapsedSeconds,
            distanceKm: distance,
            stepCount: combinedSteps > 0 ? combinedSteps : nil,
            averagePaceSecondsPerKm: safePace,
            averageCadenceStepsPerMinute: safeCadence,
            elevationGainMeters: safeElevation,
            floorsAscended: safeFloors,
            cardioMachineLevelAverage: safeAverageMachineLevel,
            cardioMachineLevelMax: safeMaxMachineLevel,
            estimatedCalories: estimatedCalories,
            metValue: supportsMachineLevel
                ? exercise.metValue * cardioUnit.metMultiplier(forMachineLevel: referenceMachineLevel)
                : exercise.metValue,
            autoIntensityRaw: cardioUnit.normalizedMachineLevelScore(safeAverageMachineLevel),
            startDate: startDate,
            cardioFitnessVO2Max: cardioFitnessVO2Max
        )
    }
}

private extension CardioSessionViewModel {
    static func formatPace(_ paceSecondsPerKm: Double) -> String {
        guard isValidPace(paceSecondsPerKm) else { return "--:--" }
        let mins = Int(paceSecondsPerKm) / 60
        let secs = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    static func isValidPace(_ paceSecondsPerKm: Double) -> Bool {
        paceSecondsPerKm >= 30
            && paceSecondsPerKm.isFinite
            && paceSecondsPerKm < 3600
    }
}
