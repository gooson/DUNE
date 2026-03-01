import CoreLocation
import Foundation

/// Protocol for air quality data fetching (testable).
protocol AirQualityFetching: Sendable {
    func fetchAirQuality(for location: CLLocation) async throws -> AirQualitySnapshot
}

/// Fetches air quality data from Open-Meteo Air Quality API.
/// Caches results for 60 minutes via AirQualitySnapshot.isStale.
/// Attribution: Open-Meteo.com (CC BY 4.0)
final class OpenMeteoAirQualityService: AirQualityFetching, @unchecked Sendable {
    private var cached: AirQualitySnapshot?
    private let lock = NSLock()
    private let session: URLSession

    private static func makeDecoder() -> JSONDecoder { JSONDecoder() }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchAirQuality(for location: CLLocation) async throws -> AirQualitySnapshot {
        if let snapshot = lock.withLock({ cached }), !snapshot.isStale {
            return snapshot
        }

        let url = try buildURL(latitude: location.coordinate.latitude,
                               longitude: location.coordinate.longitude)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenMeteoAirQualityError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenMeteoAirQualityError.httpError(httpResponse.statusCode)
        }

        let decoded = try Self.makeDecoder().decode(AirQualityResponse.self, from: data)
        let snapshot = mapToSnapshot(decoded)
        lock.withLock { cached = snapshot }
        return snapshot
    }

    // MARK: - URL

    private func buildURL(latitude: Double, longitude: Double) throws -> URL {
        guard var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality") else {
            throw OpenMeteoAirQualityError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", longitude)),
            URLQueryItem(
                name: "current",
                value: "pm10,pm2_5,us_aqi,european_aqi,ozone,nitrogen_dioxide,sulphur_dioxide,carbon_monoxide"
            ),
            URLQueryItem(
                name: "hourly",
                value: "pm10,pm2_5,us_aqi"
            ),
            URLQueryItem(name: "forecast_hours", value: "24"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components.url else {
            throw OpenMeteoAirQualityError.invalidURL
        }
        return url
    }

    // MARK: - Mapping

    private func mapToSnapshot(_ response: AirQualityResponse) -> AirQualitySnapshot {
        let current = response.current

        let hourlyItems: [AirQualitySnapshot.HourlyAirQuality]
        if let hourly = response.hourly {
            let count = hourly.time.count
            hourlyItems = (0..<Swift.min(24, count)).compactMap { i -> AirQualitySnapshot.HourlyAirQuality? in
                guard let date = OpenMeteoService.parseISO8601(hourly.time[i]),
                      i < hourly.pm2_5.count,
                      i < hourly.pm10.count else { return nil }
                return AirQualitySnapshot.HourlyAirQuality(
                    hour: date,
                    pm2_5: clampPM(hourly.pm2_5[i]),
                    pm10: clampPM(hourly.pm10[i]),
                    usAQI: clampAQI(i < hourly.us_aqi.count ? hourly.us_aqi[i] : 0)
                )
            }
        } else {
            hourlyItems = []
        }

        return AirQualitySnapshot(
            pm2_5: clampPM(current.pm2_5),
            pm10: clampPM(current.pm10),
            usAQI: clampAQI(current.us_aqi),
            europeanAQI: clampAQI(current.european_aqi),
            ozone: current.ozone.map(clampConcentration),
            nitrogenDioxide: current.nitrogen_dioxide.map(clampConcentration),
            sulphurDioxide: current.sulphur_dioxide.map(clampConcentration),
            carbonMonoxide: current.carbon_monoxide.map(clampConcentration),
            fetchedAt: Date(),
            hourlyForecast: hourlyItems
        )
    }

    /// Clamp PM values to physical range (0-1000 μg/m³).
    private func clampPM(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.max(0, Swift.min(1000, value))
    }

    /// Clamp AQI values to standard range (0-500).
    private func clampAQI(_ value: Int) -> Int {
        Swift.max(0, Swift.min(500, value))
    }

    /// Clamp general concentration values to physical range (0-100000 μg/m³).
    private func clampConcentration(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return Swift.max(0, Swift.min(100_000, value))
    }
}

// MARK: - Errors

enum OpenMeteoAirQualityError: Error, Sendable {
    case invalidResponse
    case invalidURL
    case httpError(Int)
}

// MARK: - Response Models

struct AirQualityResponse: Decodable, Sendable {
    let current: CurrentData
    let hourly: HourlyData?

    struct CurrentData: Decodable, Sendable {
        let pm10: Double
        let pm2_5: Double
        let us_aqi: Int
        let european_aqi: Int
        let ozone: Double?
        let nitrogen_dioxide: Double?
        let sulphur_dioxide: Double?
        let carbon_monoxide: Double?
    }

    struct HourlyData: Decodable, Sendable {
        let time: [String]
        let pm10: [Double]
        let pm2_5: [Double]
        let us_aqi: [Int]
    }
}
