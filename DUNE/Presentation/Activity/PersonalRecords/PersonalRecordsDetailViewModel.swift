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

    // MARK: - Derived (cached)

    private(set) var availableKinds: [ActivityPersonalRecord.Kind] = []
    private(set) var resolvedKind: ActivityPersonalRecord.Kind?
    private(set) var filteredRecords: [ActivityPersonalRecord] = []
    private(set) var chartData: [ActivityPersonalRecord] = []
    private(set) var currentBest: ActivityPersonalRecord?
    private(set) var allTimeRecords: [ActivityPersonalRecord] = []

    /// Chart axis helpers — cached alongside period.
    private(set) var chartXStrideComponent: Calendar.Component = .month
    private(set) var chartXLabelFormat: Date.FormatStyle = .dateTime.month(.abbreviated)

    func load(records: [ActivityPersonalRecord]) {
        personalRecords = records.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if lhs.kind.sortOrder != rhs.kind.sortOrder { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.value > rhs.value
        }
        rebuildDerived()
    }

    /// Called from View's .onChange when selectedPeriod or selectedKind changes.
    func rebuildDerived() {
        // Available kinds
        let kinds = Set(personalRecords.map(\.kind))
        availableKinds = kinds.sorted { $0.sortOrder < $1.sortOrder }

        // Resolved kind
        if let selectedKind, availableKinds.contains(selectedKind) {
            resolvedKind = selectedKind
        } else {
            resolvedKind = availableKinds.first
        }

        // Filtered by kind (all-time)
        let byKind: [ActivityPersonalRecord]
        if let kind = resolvedKind {
            byKind = personalRecords.filter { $0.kind == kind }
        } else {
            byKind = []
        }

        // Filtered by kind + period, newest first
        let range = selectedPeriod.dateRange()
        filteredRecords = byKind
            .filter { $0.date >= range.start && $0.date <= range.end }
            .sorted { $0.date > $1.date }

        // Chart data: oldest first
        chartData = filteredRecords.sorted { $0.date < $1.date }

        // Current best (all-time for the selected kind)
        if let kind = resolvedKind {
            if kind.isLowerBetter {
                currentBest = byKind.min { $0.value < $1.value }
            } else {
                currentBest = byKind.max { $0.value < $1.value }
            }
        } else {
            currentBest = nil
        }

        // All-time records sorted newest first
        allTimeRecords = byKind.sorted { $0.date > $1.date }

        // Chart axis format
        switch selectedPeriod {
        case .day, .week:
            chartXStrideComponent = .day
            chartXLabelFormat = .dateTime.day().month(.abbreviated)
        case .month:
            chartXStrideComponent = .weekOfMonth
            chartXLabelFormat = .dateTime.day().month(.abbreviated)
        case .sixMonths, .year:
            chartXStrideComponent = .month
            chartXLabelFormat = .dateTime.month(.abbreviated)
        }
    }
}
