import Foundation

/// Thread-safe in-memory cache for weather data with 15-minute TTL.
final class WeatherCache: @unchecked Sendable {
    private var cached: WeatherSnapshot?
    private let lock = NSLock()

    func get() -> WeatherSnapshot? {
        lock.withLock { cached }
    }

    func set(_ snapshot: WeatherSnapshot) {
        lock.withLock { cached = snapshot }
    }

    func invalidate() {
        lock.withLock { cached = nil }
    }
}
