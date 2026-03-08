import Foundation

extension BedtimeReminderLeadTime {
    var displayName: String {
        switch self {
        case .thirtyMinutes: String(localized: "30 Minutes")
        case .oneHour: String(localized: "1 Hour")
        case .twoHours: String(localized: "2 Hours")
        }
    }
}
