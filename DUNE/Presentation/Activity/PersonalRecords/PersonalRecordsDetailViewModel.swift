import Foundation
import Observation

/// ViewModel for the Personal Records detail view with period filtering.
@Observable
@MainActor
final class PersonalRecordsDetailViewModel {
    var selectedPeriod: TimePeriod = .sixMonths { didSet { invalidateDerived() } }
    var selectedKind: ActivityPersonalRecord.Kind? { didSet { invalidateDerived() } }

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

    var funComparisons: [FunComparison] {
        // Aggregate monthly totals from records
        let now = Date()
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
        let monthRecords = personalRecords.filter { $0.date >= monthStart }

        let totalVolume = monthRecords.filter { $0.kind == .sessionVolume }.reduce(0.0) { $0 + $1.value }
        let totalDistance = monthRecords.filter { $0.kind == .longestDistance }.reduce(0.0) { $0 + $1.value }
        let totalCalories = monthRecords.filter { $0.kind == .highestCalories }.reduce(0.0) { $0 + $1.value }

        return FunComparison.generate(totalVolume: totalVolume, totalDistance: totalDistance, totalCalories: totalCalories)
    }

    /// Achievement history grouped by month.
    var groupedHistory: [(month: String, events: [WorkoutRewardEvent])] {
        let calendar = Calendar.current
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
        return groups
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
        chartData = periodFiltered.sorted { $0.date < $1.date }

        if let kind, kind.isLowerBetter {
            currentBest = byKind.min { $0.value < $1.value }
        } else {
            currentBest = byKind.max { $0.value < $1.value }
        }

        allTimeRecords = byKind.sorted { $0.date > $1.date }
    }

}
