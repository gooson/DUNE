import SwiftUI

extension AirQualityLevel {
    var sfSymbol: String {
        switch self {
        case .good:          "aqi.low"
        case .moderate:      "aqi.medium"
        case .unhealthy:     "aqi.high"
        case .veryUnhealthy: "aqi.high"
        }
    }

    func color(for theme: AppTheme) -> Color {
        switch self {
        case .good:          theme.scoreExcellent
        case .moderate:      theme.scoreGood
        case .unhealthy:     DS.Color.caution
        case .veryUnhealthy: DS.Color.negative
        }
    }

}
