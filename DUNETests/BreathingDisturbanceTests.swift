import Testing
@testable import DUNE
import Foundation
import HealthKit

@Suite("BreathingDisturbanceAnalysis")
struct BreathingDisturbanceTests {

    @Test("Count-unit HealthKit samples preserve values and elevation boundaries",
          arguments: [0.0, 4.5, 9.99, 10.0, 12.5, 100.0, 100.1])
    func countUnitConversion(value: Double) throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let sample = HKQuantitySample(
            type: HKQuantityType(.appleSleepingBreathingDisturbances),
            quantity: HKQuantity(unit: .count(), doubleValue: value),
            start: start,
            end: start.addingTimeInterval(8 * 3600)
        )

        let result = BreathingDisturbanceQueryService().disturbanceSample(from: sample)

        if value > 100 {
            #expect(result == nil)
        } else {
            let converted = try #require(result)
            #expect(converted.value == value)
            #expect(converted.date == start)
            #expect(converted.isElevated == (value >= 10))
        }
    }

    // MARK: - Risk Classification

    @Test("Risk level: normal for average < 5")
    func normalRisk() {
        let level = BreathingDisturbanceAnalysis.classifyRisk(average: 3.0)
        #expect(level == .normal)
    }

    @Test("Risk level: mild for average 5-10")
    func mildRisk() {
        let level = BreathingDisturbanceAnalysis.classifyRisk(average: 7.0)
        #expect(level == .mild)
    }

    @Test("Risk level: elevated for average 10-15")
    func elevatedRisk() {
        let level = BreathingDisturbanceAnalysis.classifyRisk(average: 12.0)
        #expect(level == .elevated)
    }

    @Test("Risk level: significant for average >= 15")
    func significantRisk() {
        let level = BreathingDisturbanceAnalysis.classifyRisk(average: 20.0)
        #expect(level == .significant)
    }

    @Test("Risk level: boundary at 5")
    func boundaryAtFive() {
        #expect(BreathingDisturbanceAnalysis.classifyRisk(average: 4.99) == .normal)
        #expect(BreathingDisturbanceAnalysis.classifyRisk(average: 5.0) == .mild)
    }

    @Test("Risk level: boundary at 10")
    func boundaryAtTen() {
        #expect(BreathingDisturbanceAnalysis.classifyRisk(average: 9.99) == .mild)
        #expect(BreathingDisturbanceAnalysis.classifyRisk(average: 10.0) == .elevated)
    }

    // MARK: - Analysis

    @Test("Analyze empty samples returns normal risk")
    func analyzeEmpty() {
        let sut = BreathingDisturbanceQueryService(manager: HealthKitManager.shared)
        let result = sut.analyze(samples: [])
        #expect(result.average == nil)
        #expect(result.elevatedNightCount == 0)
        #expect(result.riskLevel == .normal)
    }

    @Test("Analyze samples computes correct average")
    func analyzeAverage() {
        let sut = BreathingDisturbanceQueryService(manager: HealthKitManager.shared)
        let now = Date()
        let samples = [
            BreathingDisturbanceSample(value: 4.0, date: now, isElevated: false),
            BreathingDisturbanceSample(value: 6.0, date: now.addingTimeInterval(-86400), isElevated: false),
            BreathingDisturbanceSample(value: 12.0, date: now.addingTimeInterval(-172800), isElevated: true),
        ]
        let result = sut.analyze(samples: samples)
        // avg = (4 + 6 + 12) / 3 = 7.33
        #expect(result.average != nil)
        let avg = result.average!
        #expect(avg > 7.0 && avg < 8.0)
        #expect(result.elevatedNightCount == 1)
        #expect(result.riskLevel == .mild)
    }

    // MARK: - Sample Model

    @Test("Sample elevated flag based on threshold")
    func sampleElevatedFlag() {
        let normal = BreathingDisturbanceSample(value: 5.0, date: Date(), isElevated: false)
        let elevated = BreathingDisturbanceSample(value: 15.0, date: Date(), isElevated: true)
        #expect(!normal.isElevated)
        #expect(elevated.isElevated)
    }
}
