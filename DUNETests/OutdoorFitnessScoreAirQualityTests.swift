import Foundation
import Testing
@testable import DUNE

@Suite("OutdoorFitnessScore AirQuality")
struct OutdoorFitnessScoreAirQualityTests {

    // MARK: - Air Quality Penalty in Score

    @Test("Good air quality has no penalty")
    func goodAirQuality() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear,
            airQualityLevel: .good
        )
        #expect(score == 100)
    }

    @Test("Moderate air quality deducts 10 points")
    func moderateAirQuality() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear,
            airQualityLevel: .moderate
        )
        #expect(score == 90)
    }

    @Test("Unhealthy air quality deducts 30 points")
    func unhealthyAirQuality() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear,
            airQualityLevel: .unhealthy
        )
        #expect(score == 70)
    }

    @Test("Very unhealthy air quality deducts 50 points")
    func veryUnhealthyAirQuality() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear,
            airQualityLevel: .veryUnhealthy
        )
        #expect(score == 50)
    }

    @Test("Nil air quality has no penalty (backward compatible)")
    func nilAirQuality() {
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .clear,
            airQualityLevel: nil
        )
        #expect(score == 100)
    }

    // MARK: - Combined Penalties

    @Test("Air quality penalty stacks with weather penalties")
    func combinedPenalties() {
        // Rain (-30) + unhealthy AQ (-30) = 40
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .rain,
            airQualityLevel: .unhealthy
        )
        #expect(score == 40)
    }

    @Test("Combined penalties clamp to 0")
    func combinedClampToZero() {
        // Thunderstorm (-60) + veryUnhealthy AQ (-50) = clamp to 0
        let score = WeatherSnapshot.calculateOutdoorScore(
            feelsLike: 20, uvIndex: 3, humidity: 0.45,
            windSpeed: 10, condition: .thunderstorm,
            airQualityLevel: .veryUnhealthy
        )
        #expect(score == 0)
    }

    // MARK: - Snapshot Integration

    @Test("Snapshot outdoorFitnessScore includes air quality")
    func snapshotWithAirQuality() {
        let aq = makeAirQuality(pm2_5: 50, pm10: 20) // PM2.5 unhealthy
        let snapshot = makeSnapshot(airQuality: aq)
        // Base 100 - 30 (unhealthy AQ) = 70
        #expect(snapshot.outdoorFitnessScore == 70)
    }

    @Test("Snapshot outdoorFitnessScore without air quality preserves original")
    func snapshotWithoutAirQuality() {
        let snapshot = makeSnapshot(airQuality: nil)
        #expect(snapshot.outdoorFitnessScore == 100)
    }

    @Test("isFavorableOutdoor false when air quality is unhealthy")
    func favorableOutdoorWithBadAQ() {
        let aq = makeAirQuality(pm2_5: 50, pm10: 20) // unhealthy
        let snapshot = makeSnapshot(airQuality: aq)
        #expect(!snapshot.isFavorableOutdoor)
    }

    @Test("isFavorableOutdoor true when air quality is moderate")
    func favorableOutdoorWithModerateAQ() {
        let aq = makeAirQuality(pm2_5: 20, pm10: 20) // moderate PM2.5, good PM10
        let snapshot = makeSnapshot(airQuality: aq)
        #expect(snapshot.isFavorableOutdoor)
    }

    @Test("isFavorableOutdoor true when air quality is nil")
    func favorableOutdoorNilAQ() {
        let snapshot = makeSnapshot(airQuality: nil)
        #expect(snapshot.isFavorableOutdoor)
    }

    // MARK: - withAirQuality

    @Test("withAirQuality attaches air quality to snapshot")
    func withAirQualityMethod() {
        let snapshot = makeSnapshot(airQuality: nil)
        #expect(snapshot.airQuality == nil)

        let aq = makeAirQuality(pm2_5: 10, pm10: 20)
        let updated = snapshot.withAirQuality(aq)
        #expect(updated.airQuality != nil)
        #expect(updated.airQuality?.pm2_5 == 10)
        #expect(updated.temperature == snapshot.temperature)
    }

    // MARK: - Hourly Score with Air Quality

    @Test("calculateOutdoorScore for hourly uses matched AQ data")
    func hourlyScoreWithAQ() {
        let now = Date()
        let hour = WeatherSnapshot.HourlyWeather(
            hour: now, temperature: 20, condition: .clear,
            feelsLike: 20, humidity: 0.45, uvIndex: 3,
            windSpeed: 10, precipitationProbability: 0
        )
        let aqHourly = [
            AirQualitySnapshot.HourlyAirQuality(
                hour: now, pm2_5: 50, pm10: 20, usAQI: 100
            ),
        ]
        // PM2.5=50 → unhealthy → -30
        let score = WeatherSnapshot.calculateOutdoorScore(for: hour, airQualityHourly: aqHourly)
        #expect(score == 70)
    }

    @Test("calculateOutdoorScore for hourly without matching AQ has no penalty")
    func hourlyScoreNoMatchingAQ() {
        let now = Date()
        let hour = WeatherSnapshot.HourlyWeather(
            hour: now, temperature: 20, condition: .clear,
            feelsLike: 20, humidity: 0.45, uvIndex: 3,
            windSpeed: 10, precipitationProbability: 0
        )
        let differentTime = now.addingTimeInterval(7200)
        let aqHourly = [
            AirQualitySnapshot.HourlyAirQuality(
                hour: differentTime, pm2_5: 100, pm10: 200, usAQI: 200
            ),
        ]
        // No matching hour → no AQ penalty
        let score = WeatherSnapshot.calculateOutdoorScore(for: hour, airQualityHourly: aqHourly)
        #expect(score == 100)
    }

    @Test("calculateOutdoorScore for hourly with nil AQ has no penalty")
    func hourlyScoreNilAQ() {
        let hour = WeatherSnapshot.HourlyWeather(
            hour: Date(), temperature: 20, condition: .clear,
            feelsLike: 20, humidity: 0.45, uvIndex: 3,
            windSpeed: 10, precipitationProbability: 0
        )
        let score = WeatherSnapshot.calculateOutdoorScore(for: hour, airQualityHourly: nil)
        #expect(score == 100)
    }

    // MARK: - Helpers

    private func makeSnapshot(
        feelsLike: Double = 20,
        condition: WeatherConditionType = .clear,
        airQuality: AirQualitySnapshot? = nil
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            temperature: feelsLike,
            feelsLike: feelsLike,
            condition: condition,
            humidity: 0.45,
            uvIndex: 3,
            windSpeed: 10,
            isDaytime: true,
            fetchedAt: Date(),
            hourlyForecast: [],
            dailyForecast: [],
            locationName: nil,
            airQuality: airQuality
        )
    }

    private func makeAirQuality(
        pm2_5: Double = 10,
        pm10: Double = 20
    ) -> AirQualitySnapshot {
        AirQualitySnapshot(
            pm2_5: pm2_5,
            pm10: pm10,
            usAQI: 50,
            europeanAQI: 30,
            ozone: nil,
            nitrogenDioxide: nil,
            sulphurDioxide: nil,
            carbonMonoxide: nil,
            fetchedAt: Date(),
            hourlyForecast: []
        )
    }
}
