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
    static func fromPM25(_ value: Double) -> AirQualityLevel {
        switch value {
        case ...15:    .good
        case 16...35:  .moderate
        case 36...75:  .unhealthy
        default:       .veryUnhealthy
        }
    }

    /// Korean grade from PM10 concentration (μg/m³).
    static func fromPM10(_ value: Double) -> AirQualityLevel {
        switch value {
        case ...30:    .good
        case 31...80:  .moderate
        case 81...150: .unhealthy
        default:       .veryUnhealthy
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
