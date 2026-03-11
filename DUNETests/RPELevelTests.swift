import Foundation
import Testing
@testable import DUNE

@Suite("RPELevel")
struct RPELevelTests {

    // MARK: - Validation

    @Test("Valid RPE values are accepted")
    func validValues() {
        for value in RPELevel.levels {
            #expect(RPELevel.validate(value) == value)
        }
    }

    @Test("Values below range return nil")
    func belowRange() {
        #expect(RPELevel.validate(5.5) == nil)
        #expect(RPELevel.validate(0) == nil)
        #expect(RPELevel.validate(-1) == nil)
    }

    @Test("Values above range return nil")
    func aboveRange() {
        #expect(RPELevel.validate(10.5) == nil)
        #expect(RPELevel.validate(11) == nil)
    }

    @Test("Non-step values snap to nearest 0.5")
    func snapping() {
        #expect(RPELevel.validate(7.3) == 7.5)
        #expect(RPELevel.validate(7.1) == 7.0)
        #expect(RPELevel.validate(8.74) == 8.5)
        #expect(RPELevel.validate(8.75) == 9.0)
    }

    // MARK: - Display

    @Test("displayLabel returns category names")
    func displayLabel() {
        #expect(RPELevel(value: 6.0).displayLabel == String(localized: "Light"))
        #expect(RPELevel(value: 7.0).displayLabel == String(localized: "Moderate"))
        #expect(RPELevel(value: 8.0).displayLabel == String(localized: "Hard"))
        #expect(RPELevel(value: 9.0).displayLabel == String(localized: "Very Hard"))
        #expect(RPELevel(value: 10.0).displayLabel == String(localized: "Max Effort"))
    }

    @Test("RIR mapping is correct")
    func rirMapping() {
        #expect(RPELevel(value: 10.0).rir == 0)
        #expect(RPELevel(value: 9.5).rir == 0)
        #expect(RPELevel(value: 9.0).rir == 1)
        #expect(RPELevel(value: 8.0).rir == 2)
        #expect(RPELevel(value: 7.0).rir == 3)
        #expect(RPELevel(value: 6.0).rir == 4)
    }

    // MARK: - Levels array

    @Test("Levels array has 9 entries from 6.0 to 10.0")
    func levelsArray() {
        #expect(RPELevel.levels.count == 9)
        #expect(RPELevel.levels.first == 6.0)
        #expect(RPELevel.levels.last == 10.0)
    }
}

@Suite("averageSetRPE")
struct AverageSetRPETests {

    let service = WorkoutIntensityService()

    // MARK: - Helpers

    private func input(rpe: Double?, type: SetType = .working) -> SetRPEInput {
        SetRPEInput(rpe: rpe, setType: type)
    }

    // MARK: - Basic

    @Test("Empty sets return nil")
    func emptySets() {
        #expect(service.averageSetRPE(sets: []) == nil)
    }

    @Test("All nil RPE returns nil")
    func allNilRPE() {
        let sets = [input(rpe: nil), input(rpe: nil)]
        #expect(service.averageSetRPE(sets: sets) == nil)
    }

    @Test("Single working set maps correctly")
    func singleSet() {
        // RPE 8.0 → mean 8.0 → mapped from 6.0-10.0 to 1-10 → 5
        let sets = [input(rpe: 8.0)]
        let result = service.averageSetRPE(sets: sets)
        #expect(result == 5)
    }

    @Test("Warmup sets are excluded")
    func warmupExcluded() {
        let sets = [
            input(rpe: 6.0, type: .warmup),
            input(rpe: 10.0, type: .working)
        ]
        // Only the working set (10.0) counts → mapped to 10
        let result = service.averageSetRPE(sets: sets)
        #expect(result == 10)
    }

    @Test("RPE 6.0 maps to effort 1")
    func minimumRPE() {
        let sets = [input(rpe: 6.0)]
        #expect(service.averageSetRPE(sets: sets) == 1)
    }

    @Test("RPE 10.0 maps to effort 10")
    func maximumRPE() {
        let sets = [input(rpe: 10.0)]
        #expect(service.averageSetRPE(sets: sets) == 10)
    }

    @Test("Mixed RPE with some nil values")
    func mixedWithNil() {
        let sets = [
            input(rpe: 7.0),
            input(rpe: nil),
            input(rpe: 9.0)
        ]
        // Mean of 7.0 and 9.0 = 8.0 → effort 5
        let result = service.averageSetRPE(sets: sets)
        #expect(result == 5)
    }

    @Test("Invalid RPE values are excluded")
    func invalidRPEExcluded() {
        let sets = [
            input(rpe: 3.0),  // Below range
            input(rpe: 8.0)   // Valid
        ]
        // Only 8.0 is valid → effort 5
        let result = service.averageSetRPE(sets: sets)
        #expect(result == 5)
    }
}
