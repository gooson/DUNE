import Foundation

/// Direction of a health metric trend over time
enum TrendDirection: String, Sendable, Hashable {
    case rising
    case falling
    case stable
    case volatile
    case insufficient
}

/// Analysis result for a health metric trend
struct TrendAnalysis: Sendable, Hashable {
    let direction: TrendDirection
    let consecutiveDays: Int
    let changePercent: Double

    init(direction: TrendDirection, consecutiveDays: Int = 0, changePercent: Double = 0) {
        self.direction = direction
        self.consecutiveDays = consecutiveDays
        self.changePercent = changePercent
    }

    static let insufficient = TrendAnalysis(direction: .insufficient)
}
