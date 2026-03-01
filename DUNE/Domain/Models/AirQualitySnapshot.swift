import Foundation

/// Domain representation of current air quality conditions.
/// Created by OpenMeteoAirQualityService from Open-Meteo Air Quality API data.
struct AirQualitySnapshot: Sendable, Hashable {
    let pm2_5: Double              // μg/m³
    let pm10: Double               // μg/m³
    let usAQI: Int                 // 0-500
    let europeanAQI: Int           // 0-500
    let ozone: Double?             // μg/m³
    let nitrogenDioxide: Double?   // μg/m³
    let sulphurDioxide: Double?    // μg/m³
    let carbonMonoxide: Double?    // μg/m³
    let fetchedAt: Date
    let hourlyForecast: [HourlyAirQuality]

    struct HourlyAirQuality: Sendable, Hashable, Identifiable {
        var id: Date { hour }
        let hour: Date
        let pm2_5: Double          // μg/m³
        let pm10: Double           // μg/m³
        let usAQI: Int
    }

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 60 * 60
    }

    /// Korean grade for PM2.5.
    var pm25Level: AirQualityLevel {
        AirQualityLevel.fromPM25(pm2_5)
    }

    /// Korean grade for PM10.
    var pm10Level: AirQualityLevel {
        AirQualityLevel.fromPM10(pm10)
    }

    /// Overall grade = worse of PM2.5 and PM10.
    var overallLevel: AirQualityLevel {
        Swift.max(pm25Level, pm10Level)
    }
}
