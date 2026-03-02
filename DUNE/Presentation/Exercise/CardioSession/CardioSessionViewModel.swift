import Foundation
import Observation

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
    private var timerTask: Task<Void, Never>?
    private var pausedAccumulated: TimeInterval = 0
    private var lastResumeDate: Date?

    // MARK: - Init

    init(
        exercise: ExerciseDefinition,
        activityType: WorkoutActivityType,
        isOutdoor: Bool,
        locationService: LocationTrackingServiceProtocol? = nil,
        calorieService: CalorieEstimating = CalorieEstimationService()
    ) {
        self.exercise = exercise
        self.activityType = activityType
        self.isOutdoor = isOutdoor
        self.locationService = isOutdoor ? (locationService ?? LocationTrackingService()) : nil
        self.calorieService = calorieService
    }

    // MARK: - Session Lifecycle

    func start() {
        guard state == .idle else { return }
        startDate = Date()
        lastResumeDate = startDate
        pausedAccumulated = 0
        state = .running
        startTimer()

        if isOutdoor, let locationService {
            Task {
                do {
                    try await locationService.startTracking()
                } catch {
                    errorMessage = String(localized: "Could not start GPS tracking. Distance will not be recorded.")
                    AppLogger.healthKit.error("[CardioSession] Location start failed: \(error.localizedDescription)")
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
        if state == .running, let resume = lastResumeDate {
            pausedAccumulated += Date().timeIntervalSince(resume)
        }
        elapsedSeconds = pausedAccumulated

        timerTask?.cancel()

        if let locationService {
            totalDistanceMeters = await locationService.stopTracking()
        }

        updateCalories()
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
                self.updateDistance()
                self.updateCalories()
            }
        }
    }

    private func updateElapsed() {
        guard let resume = lastResumeDate else { return }
        elapsedSeconds = pausedAccumulated + Date().timeIntervalSince(resume)
    }

    private func updateDistance() {
        guard let locationService else { return }
        Task {
            totalDistanceMeters = await locationService.totalDistanceMeters
        }
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

    // MARK: - Record Creation

    /// Creates an ExerciseRecord from the completed cardio session.
    func createExerciseRecord() -> (
        exerciseID: String,
        exerciseName: String,
        category: ExerciseCategory,
        duration: TimeInterval,
        distanceKm: Double?,
        estimatedCalories: Double,
        metValue: Double,
        startDate: Date
    )? {
        guard state == .finished, let startDate, elapsedSeconds > 0 else { return nil }

        let distance: Double? = totalDistanceMeters > 0 ? totalDistanceMeters / 1000.0 : nil

        return (
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
