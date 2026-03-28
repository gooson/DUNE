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
            switch self {
            case .thisWeek:
                // Rolling 7 days — matches Activity tab card
                let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                return (start, now)
            case .lastWeek:
                let start = calendar.date(byAdding: .day, value: -14, to: now) ?? now
                let end = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                return (start, end)
            case .thisMonth:
                let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
                return (start, now)
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
    var dailyWeightVolume: [DailyWeightVolumePoint] = []
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
        dailyWeightVolume = Self.buildDailyWeightVolume(
            from: filteredSnapshots, start: range.start, end: range.end
        )
        rebuildSummaryStats(from: result, period: period, allSnapshots: manualSnapshots)
    }

    static func buildDailyWeightVolume(
        from snapshots: [ManualExerciseSnapshot],
        start: Date, end: Date
    ) -> [DailyWeightVolumePoint] {
        let calendar = Calendar.current
        var dailyVolume: [Date: Double] = [:]

        for snapshot in snapshots where snapshot.totalVolume > 0 {
            let day = calendar.startOfDay(for: snapshot.date)
            dailyVolume[day, default: 0] += snapshot.totalVolume
        }

        var result: [DailyWeightVolumePoint] = []
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while current <= endDay {
            result.append(DailyWeightVolumePoint(
                date: current, volume: dailyVolume[current] ?? 0
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    // MARK: - Private

    private func triggerReload() {
        invalidateLoadRequests()
        loadTask?.cancel()
        comparison = nil
        chartDailyBreakdown = []
        dailyWeightVolume = []
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

    private func rebuildSummaryStats(from result: PeriodComparison, period: StatsPeriod, allSnapshots: [ManualExerciseSnapshot]) {
        let current = result.current
        let calendar = Calendar.current

        let durationMin = current.totalDuration / 60.0
        let durationChange = result.durationChange
        let calChange = result.calorieChange

        // Volume from manual records (weight × reps)
        let periodVolume = current.exerciseTypes.compactMap(\.totalVolume).reduce(0, +)
        let prevVolume = result.previous?.exerciseTypes.compactMap(\.totalVolume).reduce(0, +) ?? 0
        let rawVolChange = prevVolume > 0 ? ((periodVolume - prevVolume) / prevVolume * 100) : nil
        let volChange = rawVolChange.flatMap { $0.isFinite ? $0 : nil }

        // Fallback: weekly average from all records if this period has no volume
        let totalVolume: Double
        if periodVolume > 0 {
            totalVolume = periodVolume
        } else {
            let allWithVolume = allSnapshots.filter { $0.totalVolume > 0 }
            if let oldest = allWithVolume.map(\.date).min() {
                let allVol = allWithVolume.reduce(0.0) { $0 + $1.totalVolume }
                let daySpan = max(1, calendar.dateComponents([.day], from: oldest, to: Date()).day ?? 1)
                let weeks = max(1.0, Double(daySpan) / 7.0)
                totalVolume = allVol / weeks
            } else {
                totalVolume = 0
            }
        }

        summaryStats = [
            .volume(
                value: totalVolume > 0 ? totalVolume.formattedWithSeparator() : "\u{2014}",
                change: volChange.map { "\($0.formattedWithSeparator(alwaysShowSign: true))%" },
                isPositive: volChange.map { $0 >= 0 }
            ),
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

// MARK: - Daily Weight Volume Point

struct DailyWeightVolumePoint: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let volume: Double // weight × reps (kg)
}
