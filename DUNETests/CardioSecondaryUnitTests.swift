import Foundation
import Testing
@testable import DUNE

@Suite("CardioSecondaryUnit")
struct CardioSecondaryUnitTests {

    // MARK: - toKm conversion

    @Test("km unit returns value as-is")
    func toKmIdentity() {
        #expect(CardioSecondaryUnit.km.toKm(5.0) == 5.0)
    }

    @Test("meters converts to km by dividing by 1000")
    func metersToKm() {
        let result = CardioSecondaryUnit.meters.toKm(1500.0)
        #expect(result == 1.5)
    }

    @Test("floors returns nil (not a distance unit)")
    func floorsToKmNil() {
        #expect(CardioSecondaryUnit.floors.toKm(10) == nil)
    }

    @Test("count returns nil (not a distance unit)")
    func countToKmNil() {
        #expect(CardioSecondaryUnit.count.toKm(100) == nil)
    }

    @Test("none returns nil")
    func noneToKmNil() {
        #expect(CardioSecondaryUnit.timeOnly.toKm(0) == nil)
    }

    @Test("meters zero converts to zero km")
    func metersZero() {
        #expect(CardioSecondaryUnit.meters.toKm(0) == 0)
    }

    // MARK: - Field routing

    @Test("usesDistanceField is true only for km and meters")
    func usesDistanceField() {
        #expect(CardioSecondaryUnit.km.usesDistanceField == true)
        #expect(CardioSecondaryUnit.meters.usesDistanceField == true)
        #expect(CardioSecondaryUnit.floors.usesDistanceField == false)
        #expect(CardioSecondaryUnit.count.usesDistanceField == false)
        #expect(CardioSecondaryUnit.timeOnly.usesDistanceField == false)
    }

    @Test("usesRepsField is true only for floors and count")
    func usesRepsField() {
        #expect(CardioSecondaryUnit.km.usesRepsField == false)
        #expect(CardioSecondaryUnit.meters.usesRepsField == false)
        #expect(CardioSecondaryUnit.floors.usesRepsField == true)
        #expect(CardioSecondaryUnit.count.usesRepsField == true)
        #expect(CardioSecondaryUnit.timeOnly.usesRepsField == false)
    }

    @Test("distance and reps fields are mutually exclusive")
    func mutuallyExclusive() {
        for unit in CardioSecondaryUnit.allCases {
            #expect(!(unit.usesDistanceField && unit.usesRepsField),
                    "\(unit) cannot use both distance and reps fields")
        }
    }

    // MARK: - Placeholder

    @Test("placeholder returns non-empty for all units except none")
    func placeholders() {
        #expect(CardioSecondaryUnit.km.placeholder == "km")
        #expect(CardioSecondaryUnit.meters.placeholder == "m")
        #expect(CardioSecondaryUnit.floors.placeholder == "floors")
        #expect(CardioSecondaryUnit.count.placeholder == "count")
        #expect(CardioSecondaryUnit.timeOnly.placeholder == "")
    }

    // MARK: - Validation range

    @Test("validationRange exists for all units except none")
    func validationRanges() {
        #expect(CardioSecondaryUnit.km.validationRange != nil)
        #expect(CardioSecondaryUnit.meters.validationRange != nil)
        #expect(CardioSecondaryUnit.floors.validationRange != nil)
        #expect(CardioSecondaryUnit.count.validationRange != nil)
        #expect(CardioSecondaryUnit.timeOnly.validationRange == nil)
    }

    @Test("km range lower bound is 0.1 and upper bound is 500")
    func kmRange() {
        let range = CardioSecondaryUnit.km.validationRange!
        #expect(range.lowerBound == 0.1)
        #expect(range.upperBound == 500)
    }

    @Test("meters range allows up to 50000")
    func metersRange() {
        let range = CardioSecondaryUnit.meters.validationRange!
        #expect(range.lowerBound == 1)
        #expect(range.upperBound == 50_000)
    }

    // MARK: - Machine Level

    @Test("supportsMachineLevel is enabled only for machine cardio units")
    func supportsMachineLevel() {
        #expect(CardioSecondaryUnit.floors.supportsMachineLevel == true)
        #expect(CardioSecondaryUnit.timeOnly.supportsMachineLevel == true)
        #expect(CardioSecondaryUnit.km.supportsMachineLevel == false)
        #expect(CardioSecondaryUnit.meters.supportsMachineLevel == false)
        #expect(CardioSecondaryUnit.count.supportsMachineLevel == false)
    }

    @Test("machineLevelRange is 1 through 20 for supported units")
    func machineLevelRange() {
        #expect(CardioSecondaryUnit.floors.machineLevelRange == 1...20)
        #expect(CardioSecondaryUnit.timeOnly.machineLevelRange == 1...20)
        #expect(CardioSecondaryUnit.km.machineLevelRange == nil)
    }

    @Test("normalizedMachineLevel clamps to supported bounds")
    func normalizedMachineLevel() {
        #expect(CardioSecondaryUnit.timeOnly.normalizedMachineLevel(-3) == 1)
        #expect(CardioSecondaryUnit.timeOnly.normalizedMachineLevel(8) == 8)
        #expect(CardioSecondaryUnit.timeOnly.normalizedMachineLevel(99) == 20)
        #expect(CardioSecondaryUnit.km.normalizedMachineLevel(8) == nil)
    }

    @Test("normalizedMachineLevelScore maps averages into 0 to 1 range")
    func normalizedMachineLevelScore() {
        #expect(CardioSecondaryUnit.floors.normalizedMachineLevelScore(1) == 0)
        #expect(CardioSecondaryUnit.floors.normalizedMachineLevelScore(20) == 1)
        #expect(CardioSecondaryUnit.floors.normalizedMachineLevelScore(10.5) == 0.5)
        #expect(CardioSecondaryUnit.floors.normalizedMachineLevelScore(30) == 1)
        #expect(CardioSecondaryUnit.count.normalizedMachineLevelScore(5) == nil)
    }

    // MARK: - Codable roundtrip

    @Test("Codable roundtrip preserves all cases")
    func codableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for unit in CardioSecondaryUnit.allCases {
            let data = try encoder.encode(unit)
            let decoded = try decoder.decode(CardioSecondaryUnit.self, from: data)
            #expect(decoded == unit)
        }
    }

    @Test("rawValue matches expected strings for CloudKit stability")
    func rawValues() {
        #expect(CardioSecondaryUnit.km.rawValue == "km")
        #expect(CardioSecondaryUnit.meters.rawValue == "meters")
        #expect(CardioSecondaryUnit.floors.rawValue == "floors")
        #expect(CardioSecondaryUnit.count.rawValue == "count")
        // rawValue "none" is CloudKit/JSON-persisted — must remain stable
        #expect(CardioSecondaryUnit.timeOnly.rawValue == "none")
    }
}
