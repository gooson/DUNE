import Foundation

extension Date {
    private static var shortDaysAgoFormat: String { String(localized: "%@d ago") }
    private static var longDaysAgoFormat: String { String(localized: "%@ days ago") }

    private static func localizedFormat(_ format: String, value: String) -> String {
        String(format: format, locale: Locale.current, value)
    }

    /// Whether this date is in the future compared to now.
    /// Allows a 60-second tolerance to avoid false positives
    /// from DatePicker minute-level precision.
    var isFuture: Bool { self > Date().addingTimeInterval(60) }

    /// Relative freshness label for metric cards (e.g. "Today", "Yesterday", "3d ago")
    var freshnessLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return String(localized: "Today") }
        if calendar.isDateInYesterday(self) { return String(localized: "Yesterday") }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: self),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        if days > 1 {
            return Self.localizedFormat(Self.shortDaysAgoFormat, value: days.formattedWithSeparator)
        }
        return String(localized: "Today")
    }

    /// Backward-compatible label used in legacy UI.
    var relativeLabel: String? {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return nil }
        if calendar.isDateInYesterday(self) { return String(localized: "Yesterday") }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: self),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        let normalizedDays = max(1, days)
        return Self.localizedFormat(Self.longDaysAgoFormat, value: normalizedDays.formattedWithSeparator)
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
