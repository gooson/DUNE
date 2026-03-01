import CoreLocation
import Foundation

/// Fetches weather data from Open-Meteo REST API (primary weather source).
/// Caches results for 60 minutes via WeatherSnapshot.isStale.
/// Attribution: Open-Meteo.com (CC BY 4.0)
final class OpenMeteoService: WeatherFetching, @unchecked Sendable {
    private var cached: WeatherSnapshot?
    private let lock = NSLock()
    private let session: URLSession

    // JSONDecoder created per-call: not Sendable, and fetch is max once per 60 min.
    private static func makeDecoder() -> JSONDecoder { JSONDecoder() }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        if let snapshot = lock.withLock({ cached }), !snapshot.isStale {
            return snapshot
        }

        let url = try buildURL(latitude: location.coordinate.latitude,
                               longitude: location.coordinate.longitude)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenMeteoError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenMeteoError.httpError(httpResponse.statusCode)
        }

        let decoded = try Self.makeDecoder().decode(OpenMeteoResponse.self, from: data)
        let snapshot = mapToSnapshot(decoded)
        lock.withLock { cached = snapshot }
        return snapshot
    }

    // MARK: - URL

    private func buildURL(latitude: Double, longitude: Double) throws -> URL {
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            throw OpenMeteoError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,uv_index,is_day"
            ),
            URLQueryItem(
                name: "hourly",
                value: "temperature_2m,weather_code,is_day,apparent_temperature,relative_humidity_2m,uv_index,wind_speed_10m,precipitation_probability"
            ),
            URLQueryItem(name: "forecast_hours", value: "24"),
            URLQueryItem(
                name: "daily",
                value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max"
            ),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components.url else {
            throw OpenMeteoError.invalidURL
        }
        return url
    }

    // MARK: - Mapping

    private func mapToSnapshot(_ response: OpenMeteoResponse) -> WeatherSnapshot {
        let current = response.current

        let hourlyItems: [WeatherSnapshot.HourlyWeather]
        if let hourly = response.hourly {
            let count = hourly.time.count
            hourlyItems = (0..<Swift.min(24, count)).compactMap { i -> WeatherSnapshot.HourlyWeather? in
                guard let date = Self.parseISO8601(hourly.time[i]),
                      i < hourly.temperature_2m.count,
                      i < hourly.weather_code.count else { return nil }
                let feelsLikeVal = (i < (hourly.apparent_temperature?.count ?? 0))
                    ? hourly.apparent_temperature?[i] ?? hourly.temperature_2m[i]
                    : hourly.temperature_2m[i]
                let humidityVal = (i < (hourly.relative_humidity_2m?.count ?? 0))
                    ? (hourly.relative_humidity_2m?[i] ?? 50) / 100.0
                    : 0.5
                let uvVal = (i < (hourly.uv_index?.count ?? 0))
                    ? Int((hourly.uv_index?[i] ?? 0).rounded())
                    : 0
                let windVal = (i < (hourly.wind_speed_10m?.count ?? 0))
                    ? hourly.wind_speed_10m?[i] ?? 0
                    : 0
                let precipProb = (i < (hourly.precipitation_probability?.count ?? 0))
                    ? hourly.precipitation_probability?[i] ?? 0
                    : 0

                return WeatherSnapshot.HourlyWeather(
                    hour: date,
                    temperature: hourly.temperature_2m[i].clampedToPhysicalTemperature(),
                    condition: Self.mapWMOCode(hourly.weather_code[i]),
                    feelsLike: feelsLikeVal.clampedToPhysicalTemperature(),
                    humidity: Swift.max(0, Swift.min(1, humidityVal)),
                    uvIndex: Swift.max(0, Swift.min(15, uvVal)),
                    windSpeed: Swift.max(0, Swift.min(200, windVal)),
                    precipitationProbability: Swift.max(0, Swift.min(100, precipProb))
                )
            }
        } else {
            hourlyItems = []
        }

        let dailyItems: [WeatherSnapshot.DailyForecast]
        if let daily = response.daily {
            let count = daily.time.count
            dailyItems = (0..<Swift.min(7, count)).compactMap { i -> WeatherSnapshot.DailyForecast? in
                guard let date = Self.parseDateOnly(daily.time[i]),
                      i < daily.temperature_2m_max.count,
                      i < daily.temperature_2m_min.count,
                      i < daily.weather_code.count else { return nil }
                return WeatherSnapshot.DailyForecast(
                    date: date,
                    temperatureMax: daily.temperature_2m_max[i].clampedToPhysicalTemperature(),
                    temperatureMin: daily.temperature_2m_min[i].clampedToPhysicalTemperature(),
                    condition: Self.mapWMOCode(daily.weather_code[i]),
                    precipitationProbabilityMax: Swift.max(0, Swift.min(100,
                        daily.precipitation_probability_max.flatMap { i < $0.count ? $0[i] : nil } ?? 0)),
                    uvIndexMax: Swift.max(0, Swift.min(15, Int((
                        daily.uv_index_max.flatMap { i < $0.count ? $0[i] : nil } ?? 0).rounded())))
                )
            }
        } else {
            dailyItems = []
        }

        return WeatherSnapshot(
            temperature: current.temperature_2m.clampedToPhysicalTemperature(),
            feelsLike: current.apparent_temperature.clampedToPhysicalTemperature(),
            condition: Self.mapWMOCode(current.weather_code),
            humidity: Swift.max(0, Swift.min(1, current.relative_humidity_2m / 100.0)),
            uvIndex: current.uv_index.isFinite
                ? Swift.max(0, Swift.min(15, Int(current.uv_index.rounded())))
                : 0,
            windSpeed: Swift.max(0, Swift.min(200, current.wind_speed_10m)),
            isDaytime: current.is_day == 1,
            fetchedAt: Date(),
            hourlyForecast: hourlyItems,
            dailyForecast: dailyItems,
            locationName: nil
        )
    }

    /// Maps WMO weather interpretation codes to WeatherConditionType.
    /// Reference: https://open-meteo.com/en/docs
    static func mapWMOCode(_ code: Int) -> WeatherConditionType {
        switch code {
        case 0, 1:
            return .clear
        case 2:
            return .partlyCloudy
        case 3:
            return .cloudy
        case 45, 48:
            return .fog
        case 51, 53, 55:
            return .rain
        case 56, 57:
            return .sleet
        case 61, 63:
            return .rain
        case 65:
            return .heavyRain
        case 66, 67:
            return .sleet
        case 71, 73, 75, 77:
            return .snow
        case 80, 81:
            return .rain
        case 82:
            return .heavyRain
        case 85, 86:
            return .snow
        case 95:
            return .thunderstorm
        case 96, 99:
            return .thunderstorm
        default:
            return .cloudy
        }
    }

    // MARK: - ISO 8601 Parsing

    private enum DateParsing {
        // nonisolated(unsafe): ISO8601DateFormatter/DateFormatter are NSObject-based and not Sendable,
        // but these are only read after initialization (immutable in practice).
        nonisolated(unsafe) static let isoWithFractional: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()

        nonisolated(unsafe) static let isoBasic: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()

        // Open-Meteo hourly strings like "2026-02-28T14:00" lack timezone info.
        // With timezone=auto, these represent local time at the requested location.
        // We treat them as UTC-relative for display consistency.
        static let openMeteoHourly: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd'T'HH:mm"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }()

        // Open-Meteo daily strings like "2026-02-28" (date only, no time).
        // Uses .current timezone: with timezone=auto, API returns local dates matching device timezone.
        static let openMeteoDaily: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone.current
            return f
        }()
    }

    /// Parses Open-Meteo time strings. Supports full ISO 8601 and the compact "yyyy-MM-ddTHH:mm" format.
    static func parseISO8601(_ string: String) -> Date? {
        if let date = DateParsing.isoWithFractional.date(from: string) { return date }
        if let date = DateParsing.isoBasic.date(from: string) { return date }
        return DateParsing.openMeteoHourly.date(from: string)
    }

    /// Parses Open-Meteo daily date strings ("yyyy-MM-dd" format).
    static func parseDateOnly(_ string: String) -> Date? {
        DateParsing.openMeteoDaily.date(from: string)
    }
}

// MARK: - Errors

enum OpenMeteoError: Error, Sendable {
    case invalidResponse
    case invalidURL
    case httpError(Int)
}

// MARK: - Response Models

struct OpenMeteoResponse: Decodable, Sendable {
    let current: CurrentData
    let hourly: HourlyData?
    let daily: DailyData?

    struct CurrentData: Decodable, Sendable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let relative_humidity_2m: Double
        let weather_code: Int
        let wind_speed_10m: Double
        let uv_index: Double
        let is_day: Int
    }

    struct HourlyData: Decodable, Sendable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
        let apparent_temperature: [Double]?
        let relative_humidity_2m: [Double]?
        let uv_index: [Double]?
        let wind_speed_10m: [Double]?
        let precipitation_probability: [Int]?
    }

    struct DailyData: Decodable, Sendable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_probability_max: [Int]?
        let uv_index_max: [Double]?
    }
}
