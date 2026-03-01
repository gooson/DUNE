import Foundation
import Testing
@testable import DUNE

@Suite("AirQualitySnapshot")
struct AirQualitySnapshotTests {

    // MARK: - AirQualityLevel Korean Grade (PM2.5)

    @Test("PM2.5 0-15 → good")
    func pm25Good() {
        #expect(AirQualityLevel.fromPM25(0) == .good)
        #expect(AirQualityLevel.fromPM25(10) == .good)
        #expect(AirQualityLevel.fromPM25(15) == .good)
    }

    @Test("PM2.5 16-35 → moderate")
    func pm25Moderate() {
        #expect(AirQualityLevel.fromPM25(16) == .moderate)
        #expect(AirQualityLevel.fromPM25(25) == .moderate)
        #expect(AirQualityLevel.fromPM25(35) == .moderate)
    }

    @Test("PM2.5 36-75 → unhealthy")
    func pm25Unhealthy() {
        #expect(AirQualityLevel.fromPM25(36) == .unhealthy)
        #expect(AirQualityLevel.fromPM25(50) == .unhealthy)
        #expect(AirQualityLevel.fromPM25(75) == .unhealthy)
    }

    @Test("PM2.5 76+ → veryUnhealthy")
    func pm25VeryUnhealthy() {
        #expect(AirQualityLevel.fromPM25(76) == .veryUnhealthy)
        #expect(AirQualityLevel.fromPM25(150) == .veryUnhealthy)
    }

    // MARK: - AirQualityLevel Korean Grade (PM10)

    @Test("PM10 0-30 → good")
    func pm10Good() {
        #expect(AirQualityLevel.fromPM10(0) == .good)
        #expect(AirQualityLevel.fromPM10(30) == .good)
    }

    @Test("PM10 31-80 → moderate")
    func pm10Moderate() {
        #expect(AirQualityLevel.fromPM10(31) == .moderate)
        #expect(AirQualityLevel.fromPM10(80) == .moderate)
    }

    @Test("PM10 81-150 → unhealthy")
    func pm10Unhealthy() {
        #expect(AirQualityLevel.fromPM10(81) == .unhealthy)
        #expect(AirQualityLevel.fromPM10(150) == .unhealthy)
    }

    @Test("PM10 151+ → veryUnhealthy")
    func pm10VeryUnhealthy() {
        #expect(AirQualityLevel.fromPM10(151) == .veryUnhealthy)
        #expect(AirQualityLevel.fromPM10(300) == .veryUnhealthy)
    }

    // MARK: - AirQualityLevel Comparable

    @Test("Levels are ordered: good < moderate < unhealthy < veryUnhealthy")
    func levelOrdering() {
        #expect(AirQualityLevel.good < .moderate)
        #expect(AirQualityLevel.moderate < .unhealthy)
        #expect(AirQualityLevel.unhealthy < .veryUnhealthy)
    }

    @Test("Swift.max returns worse level")
    func maxLevel() {
        #expect(Swift.max(AirQualityLevel.good, .moderate) == .moderate)
        #expect(Swift.max(AirQualityLevel.unhealthy, .moderate) == .unhealthy)
        #expect(Swift.max(AirQualityLevel.good, .veryUnhealthy) == .veryUnhealthy)
    }

    // MARK: - AirQualityLevel displayName

    @Test("All levels have non-empty displayName")
    func displayNames() {
        for level in AirQualityLevel.allCases {
            #expect(!level.displayName.isEmpty)
        }
    }

    // MARK: - Snapshot Computed Properties

    @Test("pm25Level computes from pm2_5 value")
    func snapshotPM25Level() {
        let snapshot = makeSnapshot(pm2_5: 10, pm10: 20)
        #expect(snapshot.pm25Level == .good)

        let snapshot2 = makeSnapshot(pm2_5: 40, pm10: 20)
        #expect(snapshot2.pm25Level == .unhealthy)
    }

    @Test("pm10Level computes from pm10 value")
    func snapshotPM10Level() {
        let snapshot = makeSnapshot(pm2_5: 5, pm10: 25)
        #expect(snapshot.pm10Level == .good)

        let snapshot2 = makeSnapshot(pm2_5: 5, pm10: 100)
        #expect(snapshot2.pm10Level == .unhealthy)
    }

    @Test("overallLevel is worst of PM2.5 and PM10")
    func overallLevel() {
        // PM2.5=good, PM10=moderate → moderate
        let snapshot1 = makeSnapshot(pm2_5: 10, pm10: 50)
        #expect(snapshot1.overallLevel == .moderate)

        // PM2.5=unhealthy, PM10=good → unhealthy
        let snapshot2 = makeSnapshot(pm2_5: 50, pm10: 20)
        #expect(snapshot2.overallLevel == .unhealthy)

        // Both good → good
        let snapshot3 = makeSnapshot(pm2_5: 5, pm10: 10)
        #expect(snapshot3.overallLevel == .good)
    }

    @Test("isStale is true after 60 minutes")
    func staleness() {
        let recent = makeSnapshot(fetchedAt: Date())
        #expect(!recent.isStale)

        let borderline = makeSnapshot(fetchedAt: Date(timeIntervalSinceNow: -59 * 60))
        #expect(!borderline.isStale)

        let old = makeSnapshot(fetchedAt: Date(timeIntervalSinceNow: -61 * 60))
        #expect(old.isStale)
    }

    // MARK: - Boundary Values

    @Test("PM2.5 boundary at 15/16")
    func pm25Boundary() {
        #expect(AirQualityLevel.fromPM25(15) == .good)
        #expect(AirQualityLevel.fromPM25(16) == .moderate)
    }

    @Test("PM2.5 boundary at 35/36")
    func pm25BoundaryMid() {
        #expect(AirQualityLevel.fromPM25(35) == .moderate)
        #expect(AirQualityLevel.fromPM25(36) == .unhealthy)
    }

    @Test("PM2.5 boundary at 75/76")
    func pm25BoundaryHigh() {
        #expect(AirQualityLevel.fromPM25(75) == .unhealthy)
        #expect(AirQualityLevel.fromPM25(76) == .veryUnhealthy)
    }

    @Test("PM10 boundary at 30/31")
    func pm10Boundary() {
        #expect(AirQualityLevel.fromPM10(30) == .good)
        #expect(AirQualityLevel.fromPM10(31) == .moderate)
    }

    @Test("PM10 boundary at 80/81")
    func pm10BoundaryMid() {
        #expect(AirQualityLevel.fromPM10(80) == .moderate)
        #expect(AirQualityLevel.fromPM10(81) == .unhealthy)
    }

    @Test("PM10 boundary at 150/151")
    func pm10BoundaryHigh() {
        #expect(AirQualityLevel.fromPM10(150) == .unhealthy)
        #expect(AirQualityLevel.fromPM10(151) == .veryUnhealthy)
    }

    // MARK: - Fractional Boundary Values

    @Test("PM2.5 fractional values near boundaries classify correctly")
    func pm25FractionalBoundary() {
        #expect(AirQualityLevel.fromPM25(15.5) == .good)
        #expect(AirQualityLevel.fromPM25(15.9) == .good)
        #expect(AirQualityLevel.fromPM25(35.5) == .moderate)
        #expect(AirQualityLevel.fromPM25(75.5) == .unhealthy)
    }

    @Test("PM10 fractional values near boundaries classify correctly")
    func pm10FractionalBoundary() {
        #expect(AirQualityLevel.fromPM10(30.5) == .good)
        #expect(AirQualityLevel.fromPM10(80.5) == .moderate)
        #expect(AirQualityLevel.fromPM10(150.5) == .unhealthy)
    }

    // MARK: - Zero and Negative

    @Test("Zero PM values map to good")
    func zeroPM() {
        #expect(AirQualityLevel.fromPM25(0) == .good)
        #expect(AirQualityLevel.fromPM10(0) == .good)
    }

    @Test("Negative PM values map to good (clamped upstream)")
    func negativePM() {
        #expect(AirQualityLevel.fromPM25(-5) == .good)
        #expect(AirQualityLevel.fromPM10(-10) == .good)
    }

    // MARK: - Helpers

    private func makeSnapshot(
        pm2_5: Double = 10,
        pm10: Double = 20,
        usAQI: Int = 50,
        europeanAQI: Int = 30,
        fetchedAt: Date = Date()
    ) -> AirQualitySnapshot {
        AirQualitySnapshot(
            pm2_5: pm2_5,
            pm10: pm10,
            usAQI: usAQI,
            europeanAQI: europeanAQI,
            ozone: nil,
            nitrogenDioxide: nil,
            sulphurDioxide: nil,
            carbonMonoxide: nil,
            fetchedAt: fetchedAt,
            hourlyForecast: []
        )
    }
}
