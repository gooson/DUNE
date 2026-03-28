import CoreLocation
import Foundation

/// Protocol for fetching historical daily weather data.
protocol HistoricalWeatherFetching: Sendable {
    func fetchDailyWeather(latitude: Double, longitude: Double, start: Date, end: Date) async throws -> [DailyWeatherRecord]
}

/// A single day's weather summary.
struct DailyWeatherRecord: Sendable {
    let date: Date
    let temperatureMinCelsius: Double
    let temperatureMaxCelsius: Double
    let temperatureAvgCelsius: Double
    let humidityAvgPercent: Double
}

/// Fetches historical weather data from Open-Meteo Archive API.
/// Attribution: Open-Meteo.com (CC BY 4.0)
final class OpenMeteoArchiveService: HistoricalWeatherFetching, @unchecked Sendable {

    private struct CacheEntry: Sendable {
        let key: String
        let records: [DailyWeatherRecord]
        let fetchedAt: Date
    }

    private var cached: CacheEntry?
    private let lock = NSLock()
    private let session: URLSession
    private let cacheLifetime: TimeInterval = 24 * 60 * 60 // 24 hours

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDailyWeather(latitude: Double, longitude: Double, start: Date, end: Date) async throws -> [DailyWeatherRecord] {
        let formatter = Cache.dateFormatter
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        let cacheKey = "\(String(format: "%.2f", latitude)),\(String(format: "%.2f", longitude)),\(startStr),\(endStr)"

        if let cached = lock.withLock({ cached }),
           cached.key == cacheKey,
           Date().timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return cached.records
        }

        let url = try buildURL(latitude: latitude, longitude: longitude, start: startStr, end: endStr)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw OpenMeteoError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoded = try JSONDecoder().decode(ArchiveResponse.self, from: data)
        let records = mapToRecords(decoded, formatter: formatter)

        lock.withLock {
            cached = CacheEntry(key: cacheKey, records: records, fetchedAt: Date())
        }

        return records
    }

    // MARK: - URL

    private func buildURL(latitude: Double, longitude: Double, start: String, end: String) throws -> URL {
        guard var components = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive") else {
            throw OpenMeteoError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", longitude)),
            URLQueryItem(name: "start_date", value: start),
            URLQueryItem(name: "end_date", value: end),
            URLQueryItem(name: "daily", value: "temperature_2m_min,temperature_2m_max,temperature_2m_mean,relative_humidity_2m_mean"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components.url else {
            throw OpenMeteoError.invalidURL
        }
        return url
    }

    // MARK: - Response Mapping

    private func mapToRecords(_ response: ArchiveResponse, formatter: DateFormatter) -> [DailyWeatherRecord] {
        let daily = response.daily
        guard let times = daily.time,
              let tempMin = daily.temperature_2m_min,
              let tempMax = daily.temperature_2m_max,
              let tempMean = daily.temperature_2m_mean,
              let humidity = daily.relative_humidity_2m_mean else {
            return []
        }

        return zip(times.indices, times).compactMap { index, dateStr in
            guard index < tempMin.count,
                  index < tempMax.count,
                  index < tempMean.count,
                  index < humidity.count,
                  let date = formatter.date(from: dateStr) else {
                return nil
            }
            return DailyWeatherRecord(
                date: date,
                temperatureMinCelsius: tempMin[index],
                temperatureMaxCelsius: tempMax[index],
                temperatureAvgCelsius: tempMean[index],
                humidityAvgPercent: humidity[index]
            )
        }
    }

    private enum Cache {
        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }()
    }

    // MARK: - Response Models

    private struct ArchiveResponse: Decodable {
        let daily: DailyData

        struct DailyData: Decodable {
            let time: [String]?
            let temperature_2m_min: [Double]?
            let temperature_2m_max: [Double]?
            let temperature_2m_mean: [Double]?
            let relative_humidity_2m_mean: [Double]?
        }
    }
}
