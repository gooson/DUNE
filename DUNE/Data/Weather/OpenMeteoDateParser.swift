import Foundation

/// Parses Open-Meteo API date strings.
///
/// `@unchecked Sendable`: all formatter properties are configured at init
/// and never mutated afterward — safe for concurrent reads.
struct OpenMeteoDateParser: @unchecked Sendable {

    // MARK: - Cached Shared Instance

    private enum Cache {
        static let shared = OpenMeteoDateParser()
    }

    /// Shared cached instance — avoids allocating 4 DateFormatters per call.
    static var shared: OpenMeteoDateParser { Cache.shared }

    // MARK: - Formatters

    private let isoWithFractional: ISO8601DateFormatter
    private let isoBasic: ISO8601DateFormatter
    private let hourlyFormatter: DateFormatter
    private let dailyFormatter: DateFormatter

    init() {
        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoWithFractional = isoWithFractional

        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]
        self.isoBasic = isoBasic

        let hourlyFormatter = DateFormatter()
        hourlyFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        hourlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        hourlyFormatter.timeZone = TimeZone(identifier: "UTC")
        self.hourlyFormatter = hourlyFormatter

        let dailyFormatter = DateFormatter()
        dailyFormatter.dateFormat = "yyyy-MM-dd"
        dailyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dailyFormatter.timeZone = TimeZone.current
        self.dailyFormatter = dailyFormatter
    }

    func parseISO8601(_ string: String) -> Date? {
        if let date = isoWithFractional.date(from: string) { return date }
        if let date = isoBasic.date(from: string) { return date }
        return hourlyFormatter.date(from: string)
    }

    func parseDateOnly(_ string: String) -> Date? {
        dailyFormatter.date(from: string)
    }
}
