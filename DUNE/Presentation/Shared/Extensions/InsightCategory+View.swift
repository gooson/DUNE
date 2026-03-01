import SwiftUI

extension InsightCategory {
    /// Category-aware icon color for coaching insights.
    /// Single source of truth — used by TodayCoachingCard, InsightCardView, etc.
    var iconColor: Color {
        switch self {
        case .recovery: DS.Color.caution
        case .training: DS.Color.activity
        case .sleep: DS.Color.sleep
        case .motivation: DS.Color.positive
        case .recap: DS.Color.vitals
        case .weather: DS.Color.weatherRain
        case .general: DS.Color.warmGlow
        }
    }

    /// Theme-aware variant of `iconColor`.
    func iconColor(for theme: AppTheme) -> Color {
        switch self {
        case .recovery: DS.Color.caution
        case .training: DS.Color.activity
        case .sleep: DS.Color.sleep
        case .motivation: DS.Color.positive
        case .recap: DS.Color.vitals
        case .weather: DS.Color.weatherRain
        case .general: theme.accentColor
        }
    }
}
