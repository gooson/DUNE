import Foundation
import Observation

/// ViewModel for the Personal Records detail view.
@Observable
@MainActor
final class PersonalRecordsDetailViewModel {
    var personalRecords: [ActivityPersonalRecord] = []

    func load(records: [ActivityPersonalRecord]) {
        personalRecords = records.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if lhs.kind.sortOrder != rhs.kind.sortOrder { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.value > rhs.value
        }
    }
}
