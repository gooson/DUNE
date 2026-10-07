import Foundation

/// Calendar-day assignments. Template references survive week navigation without copying templates.
struct WeeklyWorkoutPlan: Codable, Equatable {
    private(set) var assignments: [String: UUID] = [:]

    func templateID(on date: Date, calendar: Calendar = .current) -> UUID? {
        assignments[Self.dayKey(date, calendar: calendar)]
    }

    mutating func assign(_ templateID: UUID?, to date: Date, calendar: Calendar = .current) {
        assignments[Self.dayKey(date, calendar: calendar)] = templateID
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        var storageCalendar = Calendar(identifier: .gregorian)
        storageCalendar.timeZone = calendar.timeZone
        let parts = storageCalendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
