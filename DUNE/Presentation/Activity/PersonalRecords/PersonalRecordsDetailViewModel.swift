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

    // MARK: - Derived (single struct to avoid multi-property re-entrant updates)

    struct DerivedState {
        var availableKinds: [ActivityPersonalRecord.Kind] = []
        var resolvedKind: ActivityPersonalRecord.Kind?
        var filteredRecords: [ActivityPersonalRecord] = []
        var chartData: [ActivityPersonalRecord] = []
        var currentBest: ActivityPersonalRecord?
        var allTimeRecords: [ActivityPersonalRecord] = []
        var chartXStrideComponent: Calendar.Component = .month
        var chartXLabelFormat: Date.FormatStyle = .dateTime.month(.abbreviated)
    }

    private(set) var derived = DerivedState()

    func load(records: [ActivityPersonalRecord]) {
        personalRecords = records.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if lhs.kind.sortOrder != rhs.kind.sortOrder { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.value > rhs.value
        }
        rebuildDerived()
    }

    /// Recompute all derived data in one assignment.
    func rebuildDerived() {
        var next = DerivedState()

        // Available kinds
        let kinds = Set(personalRecords.map(\.kind))
        next.availableKinds = kinds.sorted { $0.sortOrder < $1.sortOrder }

        // Resolved kind
        if let selectedKind, next.availableKinds.contains(selectedKind) {
            next.resolvedKind = selectedKind
        } else {
            next.resolvedKind = next.availableKinds.first
        }

        // Filtered by kind (all-time)
        let byKind: [ActivityPersonalRecord]
        if let kind = next.resolvedKind {
            byKind = personalRecords.filter { $0.kind == kind }
        } else {
            byKind = []
        }

        // Filtered by kind + period, newest first
        let range = selectedPeriod.dateRange()
        next.filteredRecords = byKind
            .filter { $0.date >= range.start && $0.date <= range.end }
            .sorted { $0.date > $1.date }

        // Chart data: oldest first
        next.chartData = next.filteredRecords.sorted { $0.date < $1.date }

        // Current best (all-time for the selected kind)
        if let kind = next.resolvedKind {
            if kind.isLowerBetter {
                next.currentBest = byKind.min { $0.value < $1.value }
            } else {
                next.currentBest = byKind.max { $0.value < $1.value }
            }
        }

        // All-time records sorted newest first
        next.allTimeRecords = byKind.sorted { $0.date > $1.date }

        // Chart axis format
        switch selectedPeriod {
        case .day, .week:
            next.chartXStrideComponent = .day
            next.chartXLabelFormat = .dateTime.day().month(.abbreviated)
        case .month:
            next.chartXStrideComponent = .weekOfMonth
            next.chartXLabelFormat = .dateTime.day().month(.abbreviated)
        case .sixMonths, .year:
            next.chartXStrideComponent = .month
            next.chartXLabelFormat = .dateTime.month(.abbreviated)
        }

        // Single atomic assignment
        derived = next
    }
}
