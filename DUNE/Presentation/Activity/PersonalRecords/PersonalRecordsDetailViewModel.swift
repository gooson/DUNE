import Foundation
import Observation

/// ViewModel for the Personal Records detail view with period filtering.
@Observable
@MainActor
final class PersonalRecordsDetailViewModel {
    var selectedPeriod: TimePeriod = .sixMonths { didSet { invalidateDerived() } }
    var selectedKind: ActivityPersonalRecord.Kind? { didSet { invalidateDerived() } }

    private let workoutService: any WorkoutQuerying
    private var recentPaceWorkouts: [ActivityPersonalRecord] = []
    private var fetchedPaceWorkouts: [ActivityPersonalRecord] = []
    private var paceLoadTask: Task<Void, Never>?
    private var paceHistoryGeneration = 0
    private(set) var hasLoadedPaceHistory = false
    private(set) var isLoadingPaceHistory = false
    private(set) var paceHistoryError: String?

    init(workoutService: any WorkoutQuerying = WorkoutQueryService(manager: .shared)) {
        self.workoutService = workoutService
    }

    /// PR periods relevant for this view (day/week excluded — PRs are sparse).
    static let availablePeriods: [TimePeriod] = [.month, .sixMonths, .year]

    // MARK: - Cached Derived Data

    private(set) var availableKinds: [ActivityPersonalRecord.Kind] = []
    private(set) var filteredByKind: [ActivityPersonalRecord] = []
    private(set) var filteredRecords: [ActivityPersonalRecord] = []
    private(set) var chartData: [ActivityPersonalRecord] = []
    private(set) var currentBest: ActivityPersonalRecord?
    private(set) var allTimeRecords: [ActivityPersonalRecord] = []

    private(set) var personalRecords: [ActivityPersonalRecord] = []

    // Reward & badge data (set externally from View's task)
    var rewardSummary: WorkoutRewardSummary = .empty
    var rewardHistory: [WorkoutRewardEvent] = []
    var unlockedBadgeKeys: Set<String> = []

    // MARK: - Derived Reward Properties

    var levelTier: RewardLevelTier {
        RewardLevelTier.tier(for: rewardSummary.level)
    }

    var nextLevelTier: RewardLevelTier? {
        RewardLevelTier.nextTier(for: rewardSummary.level)
    }

    var levelProgress: (current: Int, needed: Int, fraction: Double) {
        RewardLevelTier.levelProgress(totalPoints: rewardSummary.totalPoints, currentLevel: rewardSummary.level)
    }

    var badgeDefinitions: [WorkoutBadgeDefinition] {
        WorkoutBadgeDefinition.allDefinitions(unlockedKeys: unlockedBadgeKeys)
    }

    var unlockedBadgeCount: Int {
        badgeDefinitions.filter(\.isUnlocked).count
    }

    var totalBadgeCount: Int {
        badgeDefinitions.count
    }

    private(set) var funComparisons: [FunComparison] = []
    private(set) var groupedHistory: [(month: String, events: [WorkoutRewardEvent])] = []

    func refreshRewardDerived() {
        refreshFunComparisons()
        refreshGroupedHistory()
    }

    private func refreshFunComparisons() {
        let now = Date()
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
        let monthRecords = personalRecords.filter { $0.date >= monthStart }

        let totalVolume = monthRecords.filter { $0.kind == .sessionVolume }.reduce(0.0) { $0 + $1.value }
        let totalDistance = monthRecords.filter { $0.kind == .longestDistance }.reduce(0.0) { $0 + $1.value }
        let totalCalories = monthRecords.filter { $0.kind == .highestCalories }.reduce(0.0) { $0 + $1.value }

        funComparisons = FunComparison.generate(totalVolume: totalVolume, totalDistance: totalDistance, totalCalories: totalCalories)
    }

    private func refreshGroupedHistory() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var groups: [(month: String, events: [WorkoutRewardEvent])] = []
        var currentMonth = ""
        var currentEvents: [WorkoutRewardEvent] = []

        let sorted = rewardHistory.sorted { $0.date > $1.date }.prefix(30)
        for event in sorted {
            let month = formatter.string(from: event.date)
            if month != currentMonth {
                if !currentEvents.isEmpty {
                    groups.append((month: currentMonth, events: currentEvents))
                }
                currentMonth = month
                currentEvents = [event]
            } else {
                currentEvents.append(event)
            }
        }
        if !currentEvents.isEmpty {
            groups.append((month: currentMonth, events: currentEvents))
        }
        groupedHistory = groups
    }

    // MARK: - Sparkline Data

    /// Returns recent PR values for sparkline display (adaptive: 3-10 points).
    func sparklineData(for kind: ActivityPersonalRecord.Kind) -> [Double] {
        let byKind = personalRecords
            .filter { $0.kind == kind }
            .sorted { $0.date < $1.date }
            .map(\.value)
        let count = byKind.count
        guard count >= 2 else { return byKind }
        // Adaptive: show at most 10 points, at least 3
        let maxPoints = min(10, max(3, count))
        return Array(byKind.suffix(maxPoints))
    }

    func load(records: [ActivityPersonalRecord]) {
        personalRecords = records.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if lhs.kind.sortOrder != rhs.kind.sortOrder { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.value > rhs.value
        }
        invalidateDerived()
    }

    /// Recent workouts can render immediately while the one-year HealthKit query runs.
    func addPaceWorkouts(_ workouts: [WorkoutSummary]) {
        let updated = Self.paceRecords(from: workouts)
        guard Set(updated) != Set(recentPaceWorkouts) else { return }
        recentPaceWorkouts = updated
        fetchedPaceWorkouts = []
        paceHistoryGeneration += 1
        paceLoadTask?.cancel()
        paceLoadTask = nil
        hasLoadedPaceHistory = false
        isLoadingPaceHistory = false
        paceHistoryError = nil
        invalidateDerived()
    }

    private static func paceRecords(from workouts: [WorkoutSummary]) -> [ActivityPersonalRecord] {
        var byID: [String: ActivityPersonalRecord] = [:]
        for workout in workouts {
            guard workout.activityType.isDistanceBased,
                  let pace = workout.averagePace,
                  pace.isFinite, pace >= 60, pace <= 3600 else { continue }
            let record = ActivityPersonalRecord(
                id: "pace-workout-\(workout.id)",
                kind: .fastestPace,
                title: workout.activityType.typeName,
                value: pace,
                date: workout.date,
                isRecent: false,
                source: .healthKit,
                workoutID: workout.id
            )
            byID[record.id] = record
        }
        return Array(byID.values)
    }

    func loadPaceHistoryIfNeeded() async {
        if let paceLoadTask {
            await paceLoadTask.value
            return
        }
        guard !hasLoadedPaceHistory else { return }
        let generation = paceHistoryGeneration
        let range = TimePeriod.year.dateRange()
        isLoadingPaceHistory = true
        paceHistoryError = nil
        let task = Task { @MainActor [weak self, workoutService] in
            guard let self else { return }
            defer {
                if generation == self.paceHistoryGeneration {
                    self.isLoadingPaceHistory = false
                    self.paceLoadTask = nil
                }
            }
            do {
                let workouts = try await workoutService.fetchWorkouts(start: range.start, end: range.end)
                guard !Task.isCancelled, generation == self.paceHistoryGeneration else { return }
                self.fetchedPaceWorkouts = Self.paceRecords(from: workouts)
                self.hasLoadedPaceHistory = true
                self.invalidateDerived()
            } catch {
                guard !Task.isCancelled, generation == self.paceHistoryGeneration else { return }
                self.paceHistoryError = String(localized: "Could not load workout data")
            }
        }
        paceLoadTask = task
        await task.value
    }

    var resolvedKind: ActivityPersonalRecord.Kind? {
        if let selectedKind, availableKinds.contains(selectedKind) {
            return selectedKind
        }
        return availableKinds.first
    }

    private func invalidateDerived() {
        let kinds = Set(personalRecords.map(\.kind))
        availableKinds = kinds.sorted { $0.sortOrder < $1.sortOrder }

        let kind = resolvedKind
        let byKind: [ActivityPersonalRecord]
        if let kind {
            byKind = personalRecords.filter { $0.kind == kind }
        } else {
            byKind = []
        }
        filteredByKind = byKind

        let range = selectedPeriod.dateRange()
        let periodFiltered = byKind
            .filter { $0.date >= range.start && $0.date <= range.end }
            .sorted { $0.date > $1.date }
        filteredRecords = periodFiltered
        let chartSource: [ActivityPersonalRecord]
        if kind == .fastestPace && (!recentPaceWorkouts.isEmpty || !fetchedPaceWorkouts.isEmpty) {
            var workoutsByID: [String: ActivityPersonalRecord] = [:]
            for workout in fetchedPaceWorkouts + recentPaceWorkouts {
                workoutsByID[workout.id] = workout
            }
            let workouts = Array(workoutsByID.values)
            let workoutIDs = Set(workouts.compactMap(\.workoutID))
            let unmatchedRecords = byKind.filter { record in
                guard let workoutID = record.workoutID else { return true }
                return !workoutIDs.contains(workoutID)
            }
            chartSource = workouts + unmatchedRecords
        } else {
            chartSource = byKind
        }
        chartData = chartSource
            .filter { $0.date >= range.start && $0.date <= range.end }
            .sorted { $0.date < $1.date }

        if let kind, kind.isLowerBetter {
            currentBest = byKind.min { $0.value < $1.value }
        } else {
            currentBest = byKind.max { $0.value < $1.value }
        }

        allTimeRecords = byKind.sorted { $0.date > $1.date }
    }

}
