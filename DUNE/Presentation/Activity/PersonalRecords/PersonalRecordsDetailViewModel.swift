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
