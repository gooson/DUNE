import Foundation
import Observation
import OSLog

/// ViewModel for the This Week detail view with period switching.
@Observable
@MainActor
final class WeeklyStatsDetailViewModel {

    // MARK: - Period

    enum StatsPeriod: String, CaseIterable, Sendable, Hashable {
        case thisWeek = "This Week"
        case lastWeek = "Last Week"
        case thisMonth = "This Month"

        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            let today = calendar.startOfDay(for: now)
            switch self {
            case .thisWeek:
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
                return (weekStart, now)
            case .lastWeek:
                let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
                let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? today
                let lastWeekEnd = calendar.date(byAdding: .second, value: -1, to: thisWeekStart) ?? today
                return (lastWeekStart, lastWeekEnd)
            case .thisMonth:
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
                return (monthStart, now)
            }
        }

        /// Days for HealthKit fetch (current + comparison period).
        var fetchDays: Int {
            switch self {
            case .thisWeek, .lastWeek: 28
            case .thisMonth: 60
            }
        }

        var volumePeriod: VolumePeriod {
            switch self {
            case .thisWeek, .lastWeek: .week
            case .thisMonth: .month
            }
        }
    }

    // MARK: - Published State

    var selectedPeriod: StatsPeriod = .thisWeek {
        didSet { triggerReload() }
    }

    var comparison: PeriodComparison?
    var summaryStats: [ActivityStat] = []
    var isLoading = false
    var errorMessage: String?

    private let workoutService: WorkoutQuerying
    private var loadTask: Task<Void, Never>?

    init(workoutService: WorkoutQuerying? = nil, healthKitManager: HealthKitManager = .shared) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
    }

    // MARK: - Loading

    func loadData(manualSnapshots: [ManualExerciseSnapshot]) async {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        let period = selectedPeriod

        do {
            let workouts = try await workoutService.fetchWorkouts(days: period.fetchDays)

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            // Filter for specific period range
            let range = period.dateRange

            let filteredWorkouts: [WorkoutSummary]
            let filteredSnapshots: [ManualExerciseSnapshot]

            if period == .lastWeek {
                // For last week, filter manually since TrainingVolumeAnalysisService uses "current" = now-based
                filteredWorkouts = workouts.filter { $0.date >= range.start && $0.date <= range.end }
                filteredSnapshots = manualSnapshots.filter { $0.date >= range.start && $0.date <= range.end }
            } else {
                filteredWorkouts = workouts
                filteredSnapshots = manualSnapshots
            }

            let result = TrainingVolumeAnalysisService.analyze(
                workouts: filteredWorkouts,
                manualRecords: filteredSnapshots,
                period: period.volumePeriod
            )

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            comparison = result
            rebuildSummaryStats(from: result, period: period)

        } catch {
            AppLogger.ui.error("Weekly stats fetch failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Unable to load data.")
        }

        isLoading = false
    }

    // MARK: - Private

    private func triggerReload() {
        loadTask?.cancel()
        comparison = nil
        summaryStats = []
        isLoading = false
    }

    private func rebuildSummaryStats(from result: PeriodComparison, period: StatsPeriod) {
        let current = result.current

        let durationMin = current.totalDuration / 60.0
        let durationChange = result.durationChange
        let calChange = result.calorieChange

        summaryStats = [
            .duration(
                value: durationMin > 0 ? min(durationMin, 28_800).formattedWithSeparator() : "\u{2014}",
                change: durationChange.map { "\($0.formattedWithSeparator(alwaysShowSign: true))%" },
                isPositive: durationChange.map { $0 >= 0 }
            ),
            .calories(
                value: current.totalCalories > 0 ? current.totalCalories.formattedWithSeparator() : "\u{2014}",
                change: calChange.map { "\($0.formattedWithSeparator(alwaysShowSign: true))%" },
                isPositive: calChange.map { $0 >= 0 }
            ),
            .activeDays(
                value: current.activeDays.formattedWithSeparator
            ),
            ActivityStat(
                id: "sessions",
                icon: "figure.strengthtraining.traditional",
                iconColor: DS.Color.activity,
                title: "Sessions",
                value: current.totalSessions.formattedWithSeparator,
                unit: "",
                change: result.sessionChange.map { "\($0.formattedWithSeparator(alwaysShowSign: true))%" },
                changeIsPositive: result.sessionChange.map { $0 >= 0 }
            ),
        ]
    }
}
