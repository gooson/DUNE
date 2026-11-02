import Foundation

/// User-facing time periods use the device's local clock, never UTC or the score date.
enum LocalDayPeriod: String, Sendable {
    case morning   // 06:00–09:59
    case daytime   // 10:00–16:59
    case evening   // 17:00–21:59
    case night     // 22:00–05:59

    init(hour: Int) {
        switch hour {
        case 6..<10: self = .morning
        case 10..<17: self = .daytime
        case 17..<22: self = .evening
        default: self = .night
        }
    }

    init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        self.init(hour: calendar.component(.hour, from: date))
    }
}
