import Foundation

extension Double {
    /// Formats minutes as localized "Xh Ymin" string.
    var hoursMinutesFormatted: String {
        let totalMinutes = Int(self)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0, minutes > 0 {
            return String(localized: "\(hours)h \(minutes)min")
        }
        if hours > 0 {
            return String(localized: "\(hours)h")
        }
        return String(localized: "\(minutes)min")
    }
}
