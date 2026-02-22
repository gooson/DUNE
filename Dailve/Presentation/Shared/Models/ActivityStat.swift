import SwiftUI

/// Weekly training stat card data, created by ActivityViewModel and displayed by WeeklyStatsGrid.
struct ActivityStat: Identifiable, Sendable {
    let id: String
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String
    let change: String?
    let changeIsPositive: Bool?

    static func volume(value: String, change: String? = nil, isPositive: Bool? = nil) -> ActivityStat {
        ActivityStat(id: "volume", icon: "scalemass.fill", iconColor: DS.Color.activity,
                     title: "Volume", value: value, unit: "kg",
                     change: change, changeIsPositive: isPositive)
    }

    static func calories(value: String, change: String? = nil, isPositive: Bool? = nil) -> ActivityStat {
        ActivityStat(id: "calories", icon: "flame.fill", iconColor: .orange,
                     title: "Calories", value: value, unit: "kcal",
                     change: change, changeIsPositive: isPositive)
    }

    static func duration(value: String, change: String? = nil, isPositive: Bool? = nil) -> ActivityStat {
        ActivityStat(id: "duration", icon: "clock.fill", iconColor: DS.Color.fitness,
                     title: "Duration", value: value, unit: "min",
                     change: change, changeIsPositive: isPositive)
    }

    static func activeDays(value: String, change: String? = nil, isPositive: Bool? = nil) -> ActivityStat {
        ActivityStat(id: "activeDays", icon: "calendar", iconColor: .green,
                     title: "Active Days", value: value, unit: "days",
                     change: change, changeIsPositive: isPositive)
    }
}
