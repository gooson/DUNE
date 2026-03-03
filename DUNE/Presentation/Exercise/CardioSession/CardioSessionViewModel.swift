import Foundation
import Observation

/// Data produced by a completed cardio session — passed from ViewModel to View for persistence.
struct CardioSessionRecord: Sendable {
    let exerciseID: String
    let exerciseName: String
    let category: ExerciseCategory
    let duration: TimeInterval
    let distanceKm: Double?
    let estimatedCalories: Double
    let metValue: Double
    let startDate: Date
}

/// Manages state for an iOS cardio live tracking session.
/// Tracks elapsed time, distance (GPS for outdoor), and calorie estimation.
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
    private(set) var estimatedCalories: Double = 0
    private(set) var heartRate: Double = 0
    private(set) var walkingStepCount: Double = 0
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

    /// Current pace in "M:SS /km" format. Returns "--:--" when no distance.
    var formattedPace: String {
        guard totalDistanceMeters > 100, elapsedSeconds > 0 else { return "--:--" }
        let paceSecondsPerKm = elapsedSeconds / distanceKm
        guard paceSecondsPerKm > 0, paceSecondsPerKm.isFinite, paceSecondsPerKm < 3600 else { return "--:--" }
        let mins = Int(paceSecondsPerKm) / 60
        let secs = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Whether distance/pace should be shown (outdoor + distance-based activity).
    var showsDistance: Bool {
        isOutdoor && activityType.isDistanceBased
    }

    // MARK: - Dependencies

    private let locationService: LocationTrackingServiceProtocol?
    private let calorieService: CalorieEstimating
    private let stepsService: StepsQuerying?
    private var timerTask: Task<Void, Never>?
    private var pausedAccumulated: TimeInterval = 0
    private var lastResumeDate: Date?
    private var baselineDaySteps: Double?
    private var lastStepRefreshAt: Date?

    // MARK: - Init

    init(
        exercise: ExerciseDefinition,
        activityType: WorkoutActivityType,
        isOutdoor: Bool,
        locationService: LocationTrackingServiceProtocol? = nil,
        calorieService: CalorieEstimating = CalorieEstimationService(),
        stepsService: StepsQuerying? = nil
    ) {
        self.exercise = exercise
        self.activityType = activityType
        self.isOutdoor = isOutdoor
        self.locationService = isOutdoor ? (locationService ?? LocationTrackingService()) : nil
        self.calorieService = calorieService
        self.stepsService = activityType == .walking
            ? (stepsService ?? StepsQueryService(manager: .shared))
            : nil
    }

    // MARK: - Session Lifecycle

    func start() {
        guard state == .idle else { return }
        startDate = Date()
        lastResumeDate = startDate
        pausedAccumulated = 0
        state = .running
        walkingStepCount = 0
        baselineDaySteps = nil
        lastStepRefreshAt = nil
        startTimer()

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
                    errorMessage = String(localized: "Could not start GPS tracking. Distance will not be recorded.")
                    AppLogger.healthKit.error("[CardioSession] Location start failed: \(error)")
                }
            }
        }
    }

    func pause() {
        guard state == .running else { return }
        if let resume = lastResumeDate {
            pausedAccumulated += Date().timeIntervalSince(resume)
        }
        lastResumeDate = nil
        state = .paused
        timerTask?.cancel()
    }

    func resume() {
        guard state == .paused else { return }
        lastResumeDate = Date()
        state = .running
        startTimer()
    }

    func end() async {
        guard state == .running || state == .paused else { return }

        // Cancel timer FIRST to prevent race condition
        timerTask?.cancel()
        timerTask = nil

        // Compute final elapsed time
        if state == .running, let resume = lastResumeDate {
            pausedAccumulated += Date().timeIntervalSince(resume)
            lastResumeDate = nil
        }
        elapsedSeconds = pausedAccumulated

        // Get final distance from GPS
        if let locationService {
            totalDistanceMeters = Swift.max(0, await locationService.stopTracking())
        }

        updateCalories()
        if activityType == .walking {
            await refreshWalkingSteps(force: true)
        }
        state = .finished
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                self.updateElapsed()
                // Read distance synchronously (no nested Task)
                if let locationService = self.locationService {
                    self.totalDistanceMeters = locationService.totalDistanceMeters
                }
                self.updateCalories()
                if self.activityType == .walking {
                    Task { @MainActor [weak self] in
                        await self?.refreshWalkingSteps()
                    }
                }
            }
        }
    }

    private func updateElapsed() {
        guard let resume = lastResumeDate else { return }
        elapsedSeconds = pausedAccumulated + Date().timeIntervalSince(resume)
    }

    private func updateCalories() {
        guard elapsedSeconds > 0 else { return }
        let calories = calorieService.estimate(
            metValue: exercise.metValue,
            bodyWeightKg: CalorieEstimationService.defaultBodyWeightKg,
            durationSeconds: elapsedSeconds,
            restSeconds: 0
        )
        estimatedCalories = calories ?? 0
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

    // MARK: - Record Creation

    /// Creates a record from the completed cardio session.
    func createExerciseRecord() -> CardioSessionRecord? {
        guard state == .finished, let startDate, elapsedSeconds > 0 else { return nil }

        let distance: Double? = totalDistanceMeters > 0 ? totalDistanceMeters / 1000.0 : nil

        return CardioSessionRecord(
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            category: exercise.category,
            duration: elapsedSeconds,
            distanceKm: distance,
            estimatedCalories: estimatedCalories,
            metValue: exercise.metValue,
            startDate: startDate
        )
    }
}
