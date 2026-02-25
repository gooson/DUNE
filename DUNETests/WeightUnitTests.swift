import Testing
@testable import DUNE

@Suite("WeightUnit")
struct WeightUnitTests {

    // MARK: - Display Name

    @Test("displayName returns correct labels")
    func displayName() {
        #expect(WeightUnit.kg.displayName == "kg")
        #expect(WeightUnit.lb.displayName == "lb")
    }

    // MARK: - Conversion: fromKg

    @Test("fromKg returns same value for kg")
    func fromKgIdentity() {
        #expect(WeightUnit.kg.fromKg(100) == 100)
        #expect(WeightUnit.kg.fromKg(0) == 0)
    }

    @Test("fromKg converts correctly to lb")
    func fromKgToLb() {
        let result = WeightUnit.lb.fromKg(100)
        #expect(abs(result - 220.462) < 0.01)
    }

    @Test("fromKg handles zero")
    func fromKgZero() {
        #expect(WeightUnit.lb.fromKg(0) == 0)
    }

    // MARK: - Conversion: toKg

    @Test("toKg returns same value for kg")
    func toKgIdentity() {
        #expect(WeightUnit.kg.toKg(100) == 100)
    }

    @Test("toKg converts lb to kg correctly")
    func toKgFromLb() {
        let result = WeightUnit.lb.toKg(220.462)
        #expect(abs(result - 100) < 0.01)
    }

    @Test("toKg handles zero")
    func toKgZero() {
        #expect(WeightUnit.lb.toKg(0) == 0)
    }

    // MARK: - Round-trip

    @Test("round-trip conversion preserves value")
    func roundTrip() {
        let original = 80.5
        let converted = WeightUnit.lb.fromKg(original)
        let restored = WeightUnit.lb.toKg(converted)
        #expect(abs(restored - original) < 0.001)
    }

    // MARK: - Storage Key

    @Test("storageKey is non-empty")
    func storageKey() {
        #expect(!WeightUnit.storageKey.isEmpty)
    }
}
