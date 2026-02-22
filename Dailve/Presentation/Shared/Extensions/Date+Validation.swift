import Foundation

extension Date {
    /// Whether this date is in the future compared to now.
    /// Allows a 60-second tolerance to avoid false positives
    /// from DatePicker minute-level precision.
    var isFuture: Bool { self > Date().addingTimeInterval(60) }

    /// Relative freshness label for metric cards (e.g. "Today", "Yesterday", "3d ago")
    var freshnessLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: self),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        if days > 1 { return "\(days)d ago" }
        return "Today"
    }

    /// Backward-compatible label used in legacy UI.
    var relativeLabel: String? {
        let label = freshnessLabel
        return label == "Today" ? nil : label.replacingOccurrences(of: "d ago", with: " days ago")
    }

    /// Whole-day distance from now (today = 0).
    var daysAgo: Int {
        let calendar = Calendar.current
        return max(
            0,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: self),
                to: calendar.startOfDay(for: Date())
            ).day ?? 0
        )
    }
}
