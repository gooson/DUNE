import Foundation
import Observation
import OSLog

/// ViewModel for individual exercise type detail screen.
@Observable
@MainActor
final class ExerciseTypeDetailViewModel {
    let typeKey: String
    let displayName: String

    var selectedPeriod: VolumePeriod = .week {
        didSet { triggerReload() }
    }
    var trendData: [ChartDataPoint] = []
    var currentSummary: ExerciseTypeVolume?
    var previousSummary: ExerciseTypeVolume?
    var recentWorkouts: [WorkoutSummary] = []
    var isLoading = false

    private let workoutService: WorkoutQuerying
    private var loadTask: Task<Void, Never>?

    init(
        typeKey: String,
        displayName: String,
        workoutService: WorkoutQuerying? = nil,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.typeKey = typeKey
        self.displayName = displayName
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
    }

    // MARK: - Loading

    func loadData(manualRecords: [ExerciseRecord]) async {
        guard !isLoading else { return }
        loadTask?.cancel()
        isLoading = true

        let snapshots = manualRecords
            .filter { "manual-\($0.exerciseType)" == typeKey || $0.exerciseType == typeKey }
            .map { record in
                ManualExerciseSnapshot(
                    date: record.date,
                    exerciseType: record.exerciseType,
                    categoryRawValue: ActivityCategory.strength.rawValue,
                    duration: record.duration,
                    calories: record.estimatedCalories ?? record.calories ?? 0,
                    totalVolume: record.totalVolume
                )
            }

        let period = selectedPeriod
        let fetchDays = period.days * 2

        do {
            let workouts = try await workoutService.fetchWorkouts(days: fetchDays)

            guard !Task.isCancelled else { return }

            // Filter to this type
            let isHKType = !typeKey.hasPrefix("manual-")
            let filtered = isHKType
                ? workouts.filter { $0.activityType.rawValue == typeKey }
                : []

            let comparison = TrainingVolumeAnalysisService.analyze(
                workouts: filtered,
                manualRecords: snapshots,
                period: period
            )

            currentSummary = comparison.current.exerciseTypes.first
            previousSummary = comparison.previous?.exerciseTypes.first

            // Build trend data (daily duration in minutes)
            trendData = comparison.current.dailyBreakdown.map { day in
                let typeMinutes = day.segments
                    .filter { $0.typeKey == typeKey }
                    .reduce(0.0) { $0 + $1.duration / 60.0 }
                return ChartDataPoint(date: day.date, value: typeMinutes)
            }

            // Recent sessions (last 10)
            recentWorkouts = Array(filtered
                .sorted { $0.date > $1.date }
                .prefix(10))

        } catch {
            AppLogger.ui.error("Exercise type detail fetch failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Computed

    var durationChange: Double? {
        guard let current = currentSummary,
              let previous = previousSummary,
              previous.totalDuration > 0 else { return nil }
        let change = ((current.totalDuration - previous.totalDuration) / previous.totalDuration) * 100
        return change.isFinite ? change : nil
    }

    var calorieChange: Double? {
        guard let current = currentSummary,
              let previous = previousSummary,
              previous.totalCalories > 0 else { return nil }
        let change = ((current.totalCalories - previous.totalCalories) / previous.totalCalories) * 100
        return change.isFinite ? change : nil
    }

    // MARK: - Private

    private func triggerReload() {
        loadTask?.cancel()
        currentSummary = nil
        previousSummary = nil
        trendData = []
    }
}

// MARK: - ExerciseRecord Helpers

private extension ExerciseRecord {
    var totalVolume: Double {
        (sets ?? [])
            .filter(\.isCompleted)
            .reduce(0.0) { total, set in
                let weight = set.weight ?? 0
                let reps = Double(set.reps ?? 0)
                guard weight > 0, reps > 0 else { return total }
                return total + weight * reps
            }
    }
}
