import Foundation

extension Double {
    /// Formats minutes as "Xh Ym" string.
    var hoursMinutesFormatted: String {
        let totalMinutes = Int(self)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}
