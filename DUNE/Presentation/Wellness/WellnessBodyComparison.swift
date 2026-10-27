import Foundation

struct WellnessBodyComparison: Sendable, Equatable {
    let currentValue: Double
    let currentDate: Date
    let previousValue: Double
    let previousDate: Date

    /// The difference is in the metric's display unit; body fat uses percentage points.
    var change: Double { currentValue - previousValue }

    static func select(
        current: VitalSample?,
        history: [BodyCompositionSample],
        validRange: ClosedRange<Double>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WellnessBodyComparison? {
        let validHistory = history.filter {
            $0.value.isFinite && validRange.contains($0.value) && $0.date <= now
        }
        guard let latest = current,
              latest.value.isFinite,
              validRange.contains(latest.value),
              latest.date <= now else { return nil }

        guard let targetDate = calendar.date(byAdding: .day, value: -7, to: latest.date) else { return nil }
        let targetDay = calendar.startOfDay(for: targetDate)
        // Use the latest measured sample no later than the target calendar day.
        // The actual measurement date is retained for the card's comparison label.
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: targetDay),
              let previous = validHistory
                .filter({ $0.date < dayEnd && $0.date < latest.date })
                .max(by: { $0.date < $1.date }) else { return nil }

        return WellnessBodyComparison(
            currentValue: latest.value,
            currentDate: latest.date,
            previousValue: previous.value,
            previousDate: previous.date
        )
    }
}
