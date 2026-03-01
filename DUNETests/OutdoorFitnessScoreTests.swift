import Foundation
import Testing
@testable import DUNE

@Suite("OutdoorFitnessScore")
struct OutdoorFitnessScoreTests {

    // MARK: - Score Calculation

    @Test("Ideal conditions produce perfect score")
    func idealConditions() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 100)
    }

    @Test("Temperature below ideal range deducts points")
    func coldTemperature() {
        // 10°C → 5°C below 15°C ideal → -15 points
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 10, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 85)
    }

    @Test("Temperature above ideal range deducts points")
    func hotTemperature() {
        // 30°C → 5°C above 25°C ideal → -15 points
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 30, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 85)
    }

    @Test("Extreme heat produces very low score")
    func extremeHeat() {
        // 40°C → 15°C above 25°C → -45 points
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 40, uvIndex: 10, humidity: 0.85,
            windSpeed: 5, condition: .clear
        )
        #expect(score < 40)
    }

    @Test("Freezing temperature produces low score")
    func freezingTemperature() {
        // -5°C → 20°C below 15°C → -60 points
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: -5, uvIndex: 0, humidity: 0.45,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 40)
    }

    @Test("Boundary temperature 15°C has no penalty")
    func boundaryLow() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 15, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 100)
    }

    @Test("Boundary temperature 25°C has no penalty")
    func boundaryHigh() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 25, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 100)
    }

    // MARK: - UV Penalty

    @Test("UV 6-7 deducts 5 points")
    func moderateUV() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 6, humidity: 0.45,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 95)
    }

    @Test("UV 8-10 deducts 15 points")
    func highUV() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 8, humidity: 0.45,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 85)
    }

    @Test("UV 11+ deducts 25 points")
    func extremeUV() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 11, humidity: 0.45,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 75)
    }

    // MARK: - Humidity Penalty

    @Test("Low humidity deducts points")
    func lowHumidity() {
        // 20% humidity → 10% below 30% → 2 steps of 5% → -6 points
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.20,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 94)
    }

    @Test("High humidity deducts points")
    func highHumidity() {
        // 80% → 20% above 60% → 4 steps of 5% → -12 points
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.80,
            windSpeed: 10, condition: .clear
        )
        #expect(score == 88)
    }

    // MARK: - Wind Penalty

    @Test("Moderate wind deducts 10 points")
    func moderateWind() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 25, condition: .clear
        )
        #expect(score == 90)
    }

    @Test("Strong wind deducts 25 points")
    func strongWind() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 45, condition: .clear
        )
        #expect(score == 75)
    }

    // MARK: - Condition Penalty

    @Test("Rain deducts 30 points")
    func rain() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .rain
        )
        #expect(score == 70)
    }

    @Test("Heavy rain deducts 50 points")
    func heavyRain() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .heavyRain
        )
        #expect(score == 50)
    }

    @Test("Thunderstorm deducts 60 points")
    func thunderstorm() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .thunderstorm
        )
        #expect(score == 40)
    }

    @Test("Snow deducts 40 points")
    func snow() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .snow
        )
        #expect(score == 60)
    }

    @Test("Fog deducts 10 points")
    func fog() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .fog
        )
        #expect(score == 90)
    }

    @Test("Clear/partlyCloudy/cloudy have no condition penalty")
    func noPenaltyConditions() {
        for condition: WeatherConditionType in [.clear, .partlyCloudy, .cloudy] {
            let score = WeatherSnapshot.calculateOutdoorScore(
                feelsLike: 20, uvIndex: 3, humidity: 0.45,
                windSpeed: 10, condition: condition
            )
            #expect(score == 100, "Expected 100 for \(condition)")
        }
    }

    // MARK: - Score Clamping

    @Test("Score never exceeds 100")
    func scoreMaxClamped() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 0, humidity: 0.45,
            windSpeed: 0, condition: .clear
        )
        #expect(score == 100)
    }

    @Test("Score never goes below 0")
    func scoreMinClamped() {
        // Combine worst conditions: extreme cold + thunderstorm + strong wind + high UV + high humidity
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: -20, uvIndex: 15, humidity: 1.0,
            windSpeed: 50, condition: .thunderstorm
        )
        #expect(score == 0)
    }

    // MARK: - OutdoorFitnessLevel

    @Test("Level mapping from score")
    func levelMapping() {
        #expect(OutdoorFitnessLevel(score: 100) == .great)
        #expect(OutdoorFitnessLevel(score: 80) == .great)
        #expect(OutdoorFitnessLevel(score: 79) == .okay)
        #expect(OutdoorFitnessLevel(score: 60) == .okay)
        #expect(OutdoorFitnessLevel(score: 59) == .caution)
        #expect(OutdoorFitnessLevel(score: 40) == .caution)
        #expect(OutdoorFitnessLevel(score: 39) == .indoor)
        #expect(OutdoorFitnessLevel(score: 0) == .indoor)
    }

    @Test("Level display names are non-empty")
    func levelDisplayNames() {
        let levels: [OutdoorFitnessLevel] = [.great, .okay, .caution, .indoor]
        for level in levels {
            #expect(!level.displayName.isEmpty)
            #expect(!level.shortDisplayName.isEmpty)
            #expect(!level.systemImage.isEmpty)
        }
    }

    // MARK: - WeatherSnapshot Integration

    @Test("Snapshot outdoorFitnessScore uses current conditions")
    func snapshotScore() {
        let snapshot = makeSnapshot(feelsLike: 20, condition: .clear)
        #expect(snapshot.outdoorFitnessScore == 100)
        #expect(snapshot.outdoorFitnessLevel == .great)
    }

    @Test("Snapshot outdoorFitnessScore reflects bad weather")
    func snapshotBadWeather() {
        let snapshot = makeSnapshot(feelsLike: 20, condition: .thunderstorm)
        #expect(snapshot.outdoorFitnessScore == 40)
        #expect(snapshot.outdoorFitnessLevel == .caution)
    }

    // MARK: - Best Outdoor Hour

    @Test("bestOutdoorHour returns nil for empty forecast")
    func bestHourEmpty() {
        let snapshot = makeSnapshot(hourlyForecast: [])
        #expect(snapshot.bestOutdoorHour == nil)
    }

    @Test("bestOutdoorHour selects highest-scored hour")
    func bestHourSelection() {
        let now = Date()
        let good = WeatherSnapshot.HourlyWeather(
            hour: now, temperature: 20, condition: .clear,
            feelsLike: 20, humidity: 0.45, uvIndex: 3,
            windSpeed: 10, precipitationProbability: 0
        )
        let bad = WeatherSnapshot.HourlyWeather(
            hour: now.addingTimeInterval(3600), temperature: 20,
            condition: .heavyRain, feelsLike: 20, humidity: 0.45,
            uvIndex: 3, windSpeed: 10, precipitationProbability: 80
        )
        let snapshot = makeSnapshot(hourlyForecast: [bad, good])
        #expect(snapshot.bestOutdoorHour?.hour == good.hour)
    }

    @Test("calculateOutdoorScore for HourlyWeather")
    func hourlyScore() {
        let hour = WeatherSnapshot.HourlyWeather(
            hour: Date(), temperature: 22, condition: .clear,
            feelsLike: 22, humidity: 0.45, uvIndex: 3,
            windSpeed: 10, precipitationProbability: 0
        )
        let score = WeatherSnapshot.calculateOutdoorScore(for: hour)
        #expect(score == 100)
    }

    // MARK: - Helpers

    private func makeSnapshot(
        feelsLike: Double = 20,
        condition: WeatherConditionType = .clear,
        humidity: Double = 0.45,
        uvIndex: Int = 3,
        windSpeed: Double = 10,
        hourlyForecast: [WeatherSnapshot.HourlyWeather] = []
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            temperature: feelsLike,
            feelsLike: feelsLike,
            condition: condition,
            humidity: humidity,
            uvIndex: uvIndex,
            windSpeed: windSpeed,
            isDaytime: true,
            fetchedAt: Date(),
            hourlyForecast: hourlyForecast,
            dailyForecast: [],
            locationName: nil
        )
    }
}
