import Foundation
import Testing
@testable import DUNE

@Suite("HeartRateZoneCalculator.computeZones")
struct HeartRateZoneCalculatorTests {

    // MARK: - Edge Cases

    @Test("Empty samples returns all-zero zones")
    func emptySamples() {
        let zones = HeartRateZoneCalculator.computeZones(samples: [], maxHR: 190)
        #expect(zones.count == 5)
        for zone in zones {
            #expect(zone.durationSeconds == 0)
            #expect(zone.percentage == 0)
        }
    }

    @Test("Single sample returns all-zero zones")
    func singleSample() {
        let sample = HeartRateSample(bpm: 140, date: Date())
        let zones = HeartRateZoneCalculator.computeZones(samples: [sample], maxHR: 190)
        #expect(zones.count == 5)
        for zone in zones {
            #expect(zone.durationSeconds == 0)
            #expect(zone.percentage == 0)
        }
    }

    @Test("maxHR zero returns all-zero zones")
    func maxHRZero() {
        let now = Date()
        let samples = [
            HeartRateSample(bpm: 140, date: now),
            HeartRateSample(bpm: 150, date: now.addingTimeInterval(60))
        ]
        let zones = HeartRateZoneCalculator.computeZones(samples: samples, maxHR: 0)
        for zone in zones {
            #expect(zone.durationSeconds == 0)
            #expect(zone.percentage == 0)
        }
    }

    // MARK: - Normal Operation

    @Test("Two samples in same zone assigns 100% to that zone")
    func twoSamplesSameZone() {
        let now = Date()
        // 140/190 = 0.7368 → zone3
        let samples = [
            HeartRateSample(bpm: 140, date: now),
            HeartRateSample(bpm: 145, date: now.addingTimeInterval(60))
        ]
        let zones = HeartRateZoneCalculator.computeZones(samples: samples, maxHR: 190)
        let zone3 = zones.first { $0.zone == .zone3 }
        #expect(zone3?.percentage == 1.0)
        #expect(zone3?.durationSeconds == 60)
    }

    @Test("Multiple zones distribute correctly")
    func multipleZones() {
        let now = Date()
        // zone1: 95/190 = 0.50, zone3: 140/190 = 0.7368, zone5: 175/190 = 0.9210
        let samples = [
            HeartRateSample(bpm: 95, date: now),                          // zone1 for 60s
            HeartRateSample(bpm: 140, date: now.addingTimeInterval(60)),   // zone3 for 60s
            HeartRateSample(bpm: 175, date: now.addingTimeInterval(120))   // zone5 (last sample, no duration)
        ]
        let zones = HeartRateZoneCalculator.computeZones(samples: samples, maxHR: 190)
        let zone1 = zones.first { $0.zone == .zone1 }
        let zone3 = zones.first { $0.zone == .zone3 }
        #expect(zone1?.durationSeconds == 60)
        #expect(zone3?.durationSeconds == 60)
        #expect(zone1?.percentage == 0.5)
        #expect(zone3?.percentage == 0.5)
    }

    // MARK: - Gap Handling

    @Test("Intervals >= 300s are skipped")
    func largeGapSkipped() {
        let now = Date()
        let samples = [
            HeartRateSample(bpm: 140, date: now),                          // zone3
            HeartRateSample(bpm: 140, date: now.addingTimeInterval(300)),   // gap=300, skipped
            HeartRateSample(bpm: 140, date: now.addingTimeInterval(360))    // zone3 for 60s
        ]
        let zones = HeartRateZoneCalculator.computeZones(samples: samples, maxHR: 190)
        let zone3 = zones.first { $0.zone == .zone3 }
        // Only the second interval (60s) counts
        #expect(zone3?.durationSeconds == 60)
        #expect(zone3?.percentage == 1.0)
    }

    // MARK: - Below Zone Range

    @Test("BPM below 50% maxHR is not assigned to any zone")
    func belowZoneRange() {
        let now = Date()
        // 90/190 = 0.4736 → below zone1 (0.50)
        let samples = [
            HeartRateSample(bpm: 90, date: now),
            HeartRateSample(bpm: 90, date: now.addingTimeInterval(60))
        ]
        let zones = HeartRateZoneCalculator.computeZones(samples: samples, maxHR: 190)
        // totalDuration = 0 after filtering, so all zeros
        for zone in zones {
            #expect(zone.durationSeconds == 0)
            #expect(zone.percentage == 0)
        }
    }

    // MARK: - Boundary Values

    @Test("BPM at exactly 50% maxHR maps to zone1")
    func exactlyFiftyPercent() {
        let now = Date()
        // 95/190 = 0.50 → zone1
        let samples = [
            HeartRateSample(bpm: 95, date: now),
            HeartRateSample(bpm: 95, date: now.addingTimeInterval(60))
        ]
        let zones = HeartRateZoneCalculator.computeZones(samples: samples, maxHR: 190)
        let zone1 = zones.first { $0.zone == .zone1 }
        #expect(zone1?.percentage == 1.0)
    }

    @Test("Always returns exactly 5 zones")
    func alwaysFiveZones() {
        let now = Date()
        let samples = [
            HeartRateSample(bpm: 140, date: now),
            HeartRateSample(bpm: 145, date: now.addingTimeInterval(60))
        ]
        let zones = HeartRateZoneCalculator.computeZones(samples: samples, maxHR: 190)
        #expect(zones.count == 5)
        let rawValues = zones.map(\.zone.rawValue).sorted()
        #expect(rawValues == [1, 2, 3, 4, 5])
    }
}
