import Foundation

/// Air quality classification based on Korean Ministry of Environment standards.
/// Primary display uses Korean grade system; US AQI is shown alongside for reference.
enum AirQualityLevel: Int, Sendable, Hashable, Comparable, CaseIterable {
    case good           // 좋음
    case moderate       // 보통
    case unhealthy      // 나쁨
    case veryUnhealthy  // 매우나쁨

    static func < (lhs: AirQualityLevel, rhs: AirQualityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Korean grade from PM2.5 concentration (μg/m³).
    /// Uses half-open ranges to avoid gaps for fractional Double values.
    static func fromPM25(_ value: Double) -> AirQualityLevel {
        switch value {
        case ..<16:   .good           // 0-15
        case ..<36:   .moderate       // 16-35
        case ..<76:   .unhealthy      // 36-75
        default:      .veryUnhealthy  // 76+
        }
    }

    /// Korean grade from PM10 concentration (μg/m³).
    /// Uses half-open ranges to avoid gaps for fractional Double values.
    static func fromPM10(_ value: Double) -> AirQualityLevel {
        switch value {
        case ..<31:   .good           // 0-30
        case ..<81:   .moderate       // 31-80
        case ..<151:  .unhealthy      // 81-150
        default:      .veryUnhealthy  // 151+
        }
    }

    var displayName: String {
        switch self {
        case .good:          String(localized: "Good")
        case .moderate:      String(localized: "Moderate")
        case .unhealthy:     String(localized: "Unhealthy")
        case .veryUnhealthy: String(localized: "Very Unhealthy")
        }
    }
}
