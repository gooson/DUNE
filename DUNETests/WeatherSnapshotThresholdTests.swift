import Foundation
import Testing
@testable import DUNE

@Suite("WeatherSnapshot Thresholds")
struct WeatherSnapshotThresholdTests {

    // MARK: - Helpers

    private func makeSnapshot(
        feelsLike: Double = 20,
        humidity: Double = 0.5,
        uvIndex: Int = 3,
        windSpeed: Double = 10,
        condition: WeatherConditionType = .clear,
        fetchedAt: Date = Date(),
        airQuality: AirQualitySnapshot? = nil
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            temperature: feelsLike,
            feelsLike: feelsLike,
            condition: condition,
            humidity: humidity,
            uvIndex: uvIndex,
            windSpeed: windSpeed,
            isDaytime: true,
            fetchedAt: fetchedAt,
            hourlyForecast: [],
            dailyForecast: [],
            locationName: nil,
            airQuality: airQuality
        )
    }

    // MARK: - isExtremeHeat

    @Test("isExtremeHeat boundary: 34.9 is false, 35 is true")
    func extremeHeatBoundary() {
        #expect(makeSnapshot(feelsLike: 34.9).isExtremeHeat == false)
        #expect(makeSnapshot(feelsLike: 35).isExtremeHeat == true)
        #expect(makeSnapshot(feelsLike: 40).isExtremeHeat == true)
    }

    // MARK: - isFreezing

    @Test("isFreezing boundary: 0.1 is false, 0 is true")
    func freezingBoundary() {
        #expect(makeSnapshot(feelsLike: 0.1).isFreezing == false)
        #expect(makeSnapshot(feelsLike: 0).isFreezing == true)
        #expect(makeSnapshot(feelsLike: -5).isFreezing == true)
    }

    // MARK: - isHighUV

    @Test("isHighUV boundary: 7 is false, 8 is true")
    func highUVBoundary() {
        #expect(makeSnapshot(uvIndex: 7).isHighUV == false)
        #expect(makeSnapshot(uvIndex: 8).isHighUV == true)
    }

    // MARK: - isHighHumidity

    @Test("isHighHumidity boundary: 0.79 is false, 0.80 is true")
    func highHumidityBoundary() {
        #expect(makeSnapshot(humidity: 0.79).isHighHumidity == false)
        #expect(makeSnapshot(humidity: 0.80).isHighHumidity == true)
    }

    // MARK: - isFavorableOutdoor

    @Test("isFavorableOutdoor is true when all conditions are good")
    func favorableAllGood() {
        let snapshot = makeSnapshot(
            feelsLike: 22,
            humidity: 0.5,
            uvIndex: 3,
            windSpeed: 10,
            condition: .clear
        )
        #expect(snapshot.isFavorableOutdoor == true)
    }

    @Test("isFavorableOutdoor is false when extreme heat")
    func unfavorableExtremeHeat() {
        #expect(makeSnapshot(feelsLike: 40).isFavorableOutdoor == false)
    }

    @Test("isFavorableOutdoor is false when freezing")
    func unfavorableFreezing() {
        #expect(makeSnapshot(feelsLike: -5).isFavorableOutdoor == false)
    }

    @Test("isFavorableOutdoor is false during rain")
    func unfavorableRain() {
        #expect(makeSnapshot(condition: .rain).isFavorableOutdoor == false)
    }

    @Test("isFavorableOutdoor is false with high wind")
    func unfavorableHighWind() {
        #expect(makeSnapshot(windSpeed: 55).isFavorableOutdoor == false)
    }

    // MARK: - isStale

    @Test("isStale is false when recently fetched")
    func notStale() {
        let now = Date()
        let snapshot = makeSnapshot(fetchedAt: now)
        #expect(snapshot.isStale == false)
    }

    @Test("isStale boundary: 59 minutes ago is not stale")
    func notStaleJustBeforeThreshold() {
        let now = Date()
        let fiftyNineMinAgo = now.addingTimeInterval(-3540)
        let snapshot = makeSnapshot(fetchedAt: fiftyNineMinAgo)
        #expect(snapshot.isStale == false)
    }

    @Test("isStale is true when fetched over 1 hour ago")
    func staleAfterOneHour() {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let snapshot = makeSnapshot(fetchedAt: twoHoursAgo)
        #expect(snapshot.isStale == true)
    }
}
