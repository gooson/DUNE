import Foundation

/// Read boundaries that HealthKit positively identifies as time-limited.
/// Missing entries are ambiguous: the person may have granted full access or denied access.
struct HealthDataAccessWindow: Sendable, Equatable, Codable {
    private let limitedStartDates: [String: Date]

    init(limitedStartDates: [String: Date] = [:]) {
        self.limitedStartDates = limitedStartDates
    }

    func limitedStartDate(for typeIdentifier: String) -> Date? {
        limitedStartDates[typeIdentifier]
    }

    /// Any changed condition boundary invalidates recently derived scores.
    /// A missing entry is ambiguous, so it is treated as a change, not as full access.
    func changesConditionAccess(comparedTo previous: Self, for typeIdentifiers: [String]) -> Bool {
        typeIdentifiers.contains { identifier in
            limitedStartDates[identifier] != previous.limitedStartDates[identifier]
        }
    }

    /// Use for point-in-time samples. Interval samples may start before the boundary
    /// and end after it, so their queries need separate predicate handling.
    func pointSampleQueryStart(for typeIdentifier: String, intendedStart: Date) -> Date {
        guard let limitedStartDate = limitedStartDates[typeIdentifier] else { return intendedStart }
        return max(intendedStart, limitedStartDate)
    }
}
