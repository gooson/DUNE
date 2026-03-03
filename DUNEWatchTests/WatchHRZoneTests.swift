import Testing
@testable import DUNEWatch

@Suite("Watch HR Zone Calculations")
struct WatchHRZoneTests {

    // MARK: - Max HR Estimation

    @Test("estimateMaxHR uses 220 - age formula")
    func maxHRFromAge() {
        #expect(HeartRateZoneCalculator.estimateMaxHR(age: 30) == 190.0)
        #expect(HeartRateZoneCalculator.estimateMaxHR(age: 20) == 200.0)
        #expect(HeartRateZoneCalculator.estimateMaxHR(age: 40) == 180.0)
        #expect(HeartRateZoneCalculator.estimateMaxHR(age: 50) == 170.0)
    }

    @Test("estimateMaxHR falls back to default for unreasonable age")
    func maxHRUnreasonableAge() {
        // age 130 → 220-130=90 (< 100) → fallback
        #expect(HeartRateZoneCalculator.estimateMaxHR(age: 130) == HeartRateZoneCalculator.defaultMaxHR)
        // age -10 → 220-(-10)=230 (>= 230) → fallback
        #expect(HeartRateZoneCalculator.estimateMaxHR(age: -10) == HeartRateZoneCalculator.defaultMaxHR)
    }

    @Test("defaultMaxHR is 190")
    func defaultMaxHR() {
        #expect(HeartRateZoneCalculator.defaultMaxHR == 190.0)
    }

    // MARK: - Zone Determination (Boundary Values)

    @Test("Zone boundaries at exact thresholds")
    func zoneBoundaries() {
        // Below zone1 threshold (< 50%)
        #expect(HeartRateZone.Zone.zone(forFraction: 0.49) == nil)

        // Zone1: 50-60%
        #expect(HeartRateZone.Zone.zone(forFraction: 0.50) == .zone1)
        #expect(HeartRateZone.Zone.zone(forFraction: 0.59) == .zone1)

        // Zone2: 60-70%
        #expect(HeartRateZone.Zone.zone(forFraction: 0.60) == .zone2)
        #expect(HeartRateZone.Zone.zone(forFraction: 0.69) == .zone2)

        // Zone3: 70-80%
        #expect(HeartRateZone.Zone.zone(forFraction: 0.70) == .zone3)
        #expect(HeartRateZone.Zone.zone(forFraction: 0.79) == .zone3)

        // Zone4: 80-90%
        #expect(HeartRateZone.Zone.zone(forFraction: 0.80) == .zone4)
        #expect(HeartRateZone.Zone.zone(forFraction: 0.89) == .zone4)

        // Zone5: 90-100%
        #expect(HeartRateZone.Zone.zone(forFraction: 0.90) == .zone5)
        #expect(HeartRateZone.Zone.zone(forFraction: 1.00) == .zone5)
    }

    @Test("Zone returns nil for out-of-range fractions")
    func zoneOutOfRange() {
        #expect(HeartRateZone.Zone.zone(forFraction: 0.0) == nil)
        #expect(HeartRateZone.Zone.zone(forFraction: -0.5) == nil)
        #expect(HeartRateZone.Zone.zone(forFraction: 1.01) == nil)
    }

    // MARK: - Zone Ordering

    @Test("Zones are ordered by rawValue")
    func zoneOrdering() {
        #expect(HeartRateZone.Zone.zone1 < .zone2)
        #expect(HeartRateZone.Zone.zone2 < .zone3)
        #expect(HeartRateZone.Zone.zone3 < .zone4)
        #expect(HeartRateZone.Zone.zone4 < .zone5)
    }

    @Test("Zone allCases has 5 elements")
    func allCasesCount() {
        #expect(HeartRateZone.Zone.allCases.count == 5)
    }
}
