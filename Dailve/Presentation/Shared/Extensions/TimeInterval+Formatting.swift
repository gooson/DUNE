import Foundation

extension TimeInterval {
    /// Formats a duration as "Xh" or "Xm".
    func formattedDuration() -> String {
        let hours = self / 3600
        let mins = self / 60
        if hours >= 1 {
            return "\(hours.formattedWithSeparator(fractionDigits: 1))h"
        }
        return "\(mins.formattedWithSeparator())m"
    }
}
