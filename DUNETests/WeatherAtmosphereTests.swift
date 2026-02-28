import Foundation
import Testing
@testable import DUNE

@Suite("WeatherAtmosphere")
struct WeatherAtmosphereTests {

    // MARK: - Factory mapping

    @Test("Clear daytime produces zero intensity")
    func clearDaytime() {
        let snapshot = makeSnapshot(condition: .clear, isDaytime: true, windSpeed: 10)
        let atmo = WeatherAtmosphere.from(snapshot)
        #expect(atmo.condition == .clear)
        #expect(atmo.isDaytime == true)
        #expect(atmo.intensity == 0)
    }

    @Test("Heavy rain produces high intensity")
    func heavyRainIntensity() {
        let snapshot = makeSnapshot(condition: .heavyRain)
        let atmo = WeatherAtmosphere.from(snapshot)
        #expect(atmo.intensity == 0.8)
    }

    @Test("Thunderstorm produces high intensity")
    func thunderstormIntensity() {
        let snapshot = makeSnapshot(condition: .thunderstorm)
        let atmo = WeatherAtmosphere.from(snapshot)
        #expect(atmo.intensity == 0.8)
    }

    @Test("Wind intensity scales with speed and clamps to 1.0")
    func windIntensityClamped() {
        let mild = makeSnapshot(condition: .wind, windSpeed: 40)
        #expect(WeatherAtmosphere.from(mild).intensity == 0.5)

        let extreme = makeSnapshot(condition: .wind, windSpeed: 120)
        #expect(WeatherAtmosphere.from(extreme).intensity == 1.0)
    }

    @Test("Night is reflected in atmosphere")
    func nightMode() {
        let snapshot = makeSnapshot(condition: .rain, isDaytime: false)
        let atmo = WeatherAtmosphere.from(snapshot)
        #expect(atmo.isDaytime == false)
    }

    @Test("Default atmosphere is clear daytime with zero intensity")
    func defaultAtmosphere() {
        let atmo = WeatherAtmosphere.default
        #expect(atmo.condition == .clear)
        #expect(atmo.isDaytime == true)
        #expect(atmo.intensity == 0)
    }

    // MARK: - Snapshot computed properties

    @Test("isExtremeHeat triggers at 35°C feels-like")
    func extremeHeat() {
        #expect(makeSnapshot(feelsLike: 35).isExtremeHeat)
        #expect(!makeSnapshot(feelsLike: 34).isExtremeHeat)
    }

    @Test("isFreezing triggers at 0°C feels-like")
    func freezing() {
        #expect(makeSnapshot(feelsLike: 0).isFreezing)
        #expect(makeSnapshot(feelsLike: -5).isFreezing)
        #expect(!makeSnapshot(feelsLike: 1).isFreezing)
    }

    @Test("isHighUV triggers at UV 8+")
    func highUV() {
        #expect(makeSnapshot(uvIndex: 8).isHighUV)
        #expect(!makeSnapshot(uvIndex: 7).isHighUV)
    }

    @Test("isHighHumidity triggers at 80%+")
    func highHumidity() {
        #expect(makeSnapshot(humidity: 0.8).isHighHumidity)
        #expect(!makeSnapshot(humidity: 0.79).isHighHumidity)
    }

    @Test("isFavorableOutdoor is true for mild clear day")
    func favorableOutdoor() {
        let snapshot = makeSnapshot(
            condition: .clear,
            feelsLike: 22,
            humidity: 0.5,
            uvIndex: 5,
            windSpeed: 15
        )
        #expect(snapshot.isFavorableOutdoor)
    }

    @Test("isFavorableOutdoor is false during thunderstorm")
    func unfavorableThunderstorm() {
        let snapshot = makeSnapshot(condition: .thunderstorm, feelsLike: 22)
        #expect(!snapshot.isFavorableOutdoor)
    }

    @Test("isFavorableOutdoor is false with extreme heat")
    func unfavorableHeat() {
        let snapshot = makeSnapshot(feelsLike: 40)
        #expect(!snapshot.isFavorableOutdoor)
    }

    @Test("isStale is true after 15 minutes")
    func staleness() {
        let recent = makeSnapshot(fetchedAt: Date())
        #expect(!recent.isStale)

        let old = makeSnapshot(fetchedAt: Date(timeIntervalSinceNow: -16 * 60))
        #expect(old.isStale)
    }

    // MARK: - Helpers

    private func makeSnapshot(
        condition: WeatherConditionType = .clear,
        feelsLike: Double = 22,
        humidity: Double = 0.5,
        uvIndex: Int = 3,
        windSpeed: Double = 10,
        isDaytime: Bool = true,
        fetchedAt: Date = Date()
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            temperature: feelsLike,
            feelsLike: feelsLike,
            condition: condition,
            humidity: humidity,
            uvIndex: uvIndex,
            windSpeed: windSpeed,
            isDaytime: isDaytime,
            fetchedAt: fetchedAt,
            hourlyForecast: []
        )
    }
}
