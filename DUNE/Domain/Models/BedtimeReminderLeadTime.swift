import Foundation

enum BedtimeReminderLeadTime: Int, CaseIterable, Sendable {
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120

    static let storageKey = "bedtimeReminderLeadTime"
    static let defaultValue: BedtimeReminderLeadTime = .twoHours

    var minutes: Int { rawValue }
}
