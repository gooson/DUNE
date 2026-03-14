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

        var displayName: String {
            switch self {
            case .thisWeek: String(localized: "This Week")
            case .lastWeek: String(localized: "Last Week")
            case .thisMonth: String(localized: "This Month")
            }
        }
    }

    // MARK: - Published State

    var selectedPeriod: StatsPeriod = .thisWeek {
        didSet { triggerReload() }
    }

    var comparison: PeriodComparison?
    var chartDailyBreakdown: [DailyVolumePoint] = []
    var summaryStats: [ActivityStat] = []
    var isLoading = false
    var errorMessage: String?

    private let workoutService: WorkoutQuerying
    private var loadTask: Task<Void, Never>?
    private var loadRequestID = 0

    init(workoutService: WorkoutQuerying? = nil, healthKitManager: HealthKitManager = .shared) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
    }

    // MARK: - Loading

    func loadData(manualSnapshots: [ManualExerciseSnapshot]) async {
        let requestID = beginLoadRequest()
        isLoading = true
        errorMessage = nil
        defer { finishLoadRequest(requestID) }

        let period = selectedPeriod
        let calendar = Calendar.current
        let range = period.dateRange
        let historyEnd = range.end
        let historyEndDay = calendar.startOfDay(for: historyEnd)
        let historyStart = calendar.date(byAdding: .day, value: -(period.fetchDays - 1), to: historyEndDay) ?? historyEndDay
        let historySnapshots = manualSnapshots.filter { $0.date >= historyStart && $0.date <= historyEnd }

        let workoutResult = await fetchWorkouts(start: historyStart, end: historyEnd)
        let workouts = workoutResult.workouts

        guard isCurrentLoadRequest(requestID) else { return }

        if workoutResult.didFail && historySnapshots.isEmpty {
            errorMessage = String(localized: "Unable to load data.")
            return
        }

        guard isCurrentLoadRequest(requestID) else { return }
        chartDailyBreakdown = TrainingVolumeAnalysisService.buildHistoryDailyBreakdown(
            workouts: workouts,
            manualRecords: historySnapshots,
            start: historyStart,
            end: historyEnd
        )

        let filteredWorkouts: [WorkoutSummary]
        let filteredSnapshots: [ManualExerciseSnapshot]

        if period == .lastWeek {
            // For last week, filter manually since TrainingVolumeAnalysisService uses "current" = now-based
            filteredWorkouts = workouts.filter { $0.date >= range.start && $0.date <= range.end }
            filteredSnapshots = manualSnapshots.filter { $0.date >= range.start && $0.date <= range.end }
        } else {
            filteredWorkouts = workouts
            filteredSnapshots = historySnapshots
        }

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: filteredWorkouts,
            manualRecords: filteredSnapshots,
            period: period.volumePeriod
        )

        guard isCurrentLoadRequest(requestID) else { return }

        comparison = result
        rebuildSummaryStats(from: result, period: period)
    }

    // MARK: - Private

    private func triggerReload() {
        invalidateLoadRequests()
        loadTask?.cancel()
        comparison = nil
        chartDailyBreakdown = []
        summaryStats = []
        isLoading = false
    }

    private func beginLoadRequest() -> Int {
        loadRequestID += 1
        return loadRequestID
    }

    private func invalidateLoadRequests() {
        loadRequestID += 1
    }

    private func isCurrentLoadRequest(_ requestID: Int) -> Bool {
        requestID == loadRequestID && !Task.isCancelled
    }

    private func finishLoadRequest(_ requestID: Int) {
        if requestID == loadRequestID {
            isLoading = false
        }
    }

    private func fetchWorkouts(start: Date, end: Date) async -> (workouts: [WorkoutSummary], didFail: Bool) {
        do {
            return (try await workoutService.fetchWorkouts(start: start, end: end), false)
        } catch {
            AppLogger.ui.error("Weekly stats fetch failed: \(error.localizedDescription)")
            return ([], true)
        }
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
                title: String(localized: "Sessions"),
                value: current.totalSessions.formattedWithSeparator,
                unit: "",
                change: result.sessionChange.map { "\($0.formattedWithSeparator(alwaysShowSign: true))%" },
                changeIsPositive: result.sessionChange.map { $0 >= 0 }
            ),
        ]
    }
}
