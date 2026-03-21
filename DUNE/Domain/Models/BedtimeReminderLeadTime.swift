import Foundation

enum BedtimeReminderLeadTime: Int, CaseIterable, Sendable {
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120

    static let storageKey = generalStorageKey
    static let defaultValue: BedtimeReminderLeadTime = generalDefaultValue
    static let generalStorageKey = "bedtimeReminderLeadTime"
    static let watchStorageKey = "appleWatchBedtimeReminderLeadTime"
    static let generalDefaultValue: BedtimeReminderLeadTime = .twoHours
    static let watchDefaultValue: BedtimeReminderLeadTime = .oneHour

    var minutes: Int { rawValue }
}
