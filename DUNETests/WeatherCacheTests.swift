import Foundation
import Testing
@testable import DUNE

@Suite("WeatherCache")
struct WeatherCacheTests {

    @Test("Empty cache returns nil")
    func emptyCache() {
        let cache = WeatherCache()
        #expect(cache.get() == nil)
    }

    @Test("Set and get returns stored snapshot")
    func setAndGet() {
        let cache = WeatherCache()
        let snapshot = makeSnapshot()
        cache.set(snapshot)
        let result = cache.get()
        #expect(result != nil)
        #expect(result?.temperature == snapshot.temperature)
    }

    @Test("Invalidate clears the cache")
    func invalidate() {
        let cache = WeatherCache()
        cache.set(makeSnapshot())
        cache.invalidate()
        #expect(cache.get() == nil)
    }

    @Test("Overwrite replaces previous value")
    func overwrite() {
        let cache = WeatherCache()
        cache.set(makeSnapshot(temperature: 10))
        cache.set(makeSnapshot(temperature: 30))
        #expect(cache.get()?.temperature == 30)
    }

    // MARK: - Helpers

    private func makeSnapshot(temperature: Double = 22) -> WeatherSnapshot {
        WeatherSnapshot(
            temperature: temperature,
            feelsLike: temperature,
            condition: .clear,
            humidity: 0.5,
            uvIndex: 3,
            windSpeed: 10,
            isDaytime: true,
            fetchedAt: Date(),
            hourlyForecast: []
        )
    }
}
