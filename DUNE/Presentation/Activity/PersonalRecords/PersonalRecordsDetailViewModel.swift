import Foundation
import Observation

/// ViewModel for the Personal Records detail view with period filtering.
@Observable
@MainActor
final class PersonalRecordsDetailViewModel {
    var personalRecords: [ActivityPersonalRecord] = []
    var selectedPeriod: TimePeriod = .sixMonths
    var selectedKind: ActivityPersonalRecord.Kind?

    /// PR periods relevant for this view (day/week excluded — PRs are sparse).
    static let availablePeriods: [TimePeriod] = [.month, .sixMonths, .year]

    func load(records: [ActivityPersonalRecord]) {
        personalRecords = records.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if lhs.kind.sortOrder != rhs.kind.sortOrder { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.value > rhs.value
        }
    }

    // MARK: - Derived Data

    var availableKinds: [ActivityPersonalRecord.Kind] {
        let kinds = Set(personalRecords.map(\.kind))
        return kinds.sorted { $0.sortOrder < $1.sortOrder }
    }

    var resolvedKind: ActivityPersonalRecord.Kind? {
        if let selectedKind, availableKinds.contains(selectedKind) {
            return selectedKind
        }
        return availableKinds.first
    }

    var filteredByKind: [ActivityPersonalRecord] {
        guard let kind = resolvedKind else { return [] }
        return personalRecords.filter { $0.kind == kind }
    }

    /// Records filtered by kind AND period, sorted newest first.
    var filteredRecords: [ActivityPersonalRecord] {
        let range = selectedPeriod.dateRange()
        return filteredByKind
            .filter { $0.date >= range.start && $0.date <= range.end }
            .sorted { $0.date > $1.date }
    }

    /// Chart data: filtered records sorted oldest first (date ascending).
    var chartData: [ActivityPersonalRecord] {
        filteredRecords.sorted { $0.date < $1.date }
    }

    /// Current best record for the selected kind (across all time, not just period).
    var currentBest: ActivityPersonalRecord? {
        let allForKind = filteredByKind
        guard let kind = resolvedKind else { return nil }
        if kind.isLowerBetter {
            return allForKind.min { $0.value < $1.value }
        }
        return allForKind.max { $0.value < $1.value }
    }

    /// All-time record grid (not period-filtered), sorted newest first.
    var allTimeRecords: [ActivityPersonalRecord] {
        filteredByKind.sorted { $0.date > $1.date }
    }
}
