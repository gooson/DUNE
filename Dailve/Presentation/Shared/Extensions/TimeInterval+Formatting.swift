import Foundation

extension TimeInterval {
    /// Formats a duration as "Xh" or "Xm".
    func formattedDuration() -> String {
        let hours = self / 3600
        let mins = self / 60
        if hours >= 1 {
            return String(format: "%.1fh", hours)
        }
        return String(format: "%.0fm", mins)
    }
}
