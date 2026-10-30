import Foundation

enum ConditionInsightGuidance {
    static func message(status: ConditionScore.Status, period: LocalDayPeriod) -> String {
        if period == .night {
            return String(localized: "Wind down for a restful night")
        }
        switch status {
        case .excellent:
            return String(localized: "A great day to try high-intensity workouts or challenging goals. Your body is well-recovered, so push yourself a bit more than usual.")
        case .good:
            return String(localized: "Good state to maintain your regular workout routine. Keep up the balanced activity to sustain your condition.")
        case .fair:
            return String(localized: "Moderate-intensity activities are recommended. Maintaining a regular sleep pattern can help improve your condition.")
        case .tired:
            return String(localized: "Light walks or stretching-focused activities are recommended. Focus on recovery with adequate sleep and rest.")
        case .warning:
            return String(localized: "Prioritize rest today. Stick to low-intensity activities and focus on improving your sleep quality.")
        }
    }
}
