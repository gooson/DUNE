import CoreLocation
import Foundation

struct OpenMeteoRequestLocation: Sendable, Hashable {
    let latitude: Double
    let longitude: Double

    init(location: CLLocation) {
        self.latitude = Self.normalizedCoordinate(location.coordinate.latitude)
        self.longitude = Self.normalizedCoordinate(location.coordinate.longitude)
    }

    private static func normalizedCoordinate(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

struct OpenMeteoDateParser {
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
