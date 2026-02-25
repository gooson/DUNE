import Foundation

/// A continuous period of consecutive workout days.
struct StreakPeriod: Sendable, Hashable, Identifiable {
    let id: Date  // startDate
    let startDate: Date
    let endDate: Date
    let days: Int
}
