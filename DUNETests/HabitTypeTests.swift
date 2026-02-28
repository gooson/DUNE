import Foundation
import Testing
@testable import DUNE

@Suite("HabitType")
struct HabitTypeTests {

    // MARK: - HabitType rawValue round-trip

    @Test("HabitType rawValue round-trip for all cases")
    func rawValueRoundTrip() {
        for type in HabitType.allCases {
            let restored = HabitType(rawValue: type.rawValue)
            #expect(restored == type)
        }
    }

    @Test("HabitType has exactly 3 cases")
    func caseCount() {
        #expect(HabitType.allCases.count == 3)
    }

    @Test("HabitType rawValues are stable strings")
    func stableRawValues() {
        #expect(HabitType.check.rawValue == "check")
        #expect(HabitType.duration.rawValue == "duration")
        #expect(HabitType.count.rawValue == "count")
    }

    // MARK: - HabitFrequency

    @Test("HabitFrequency.daily isDaily returns true")
    func dailyIsDaily() {
        let freq = HabitFrequency.daily
        #expect(freq.isDaily == true)
        #expect(freq.weeklyTarget == nil)
    }

    @Test("HabitFrequency.weekly returns correct target")
    func weeklyTarget() {
        let freq = HabitFrequency.weekly(targetDays: 3)
        #expect(freq.isDaily == false)
        #expect(freq.weeklyTarget == 3)
    }

    @Test("HabitFrequency equality")
    func frequencyEquality() {
        #expect(HabitFrequency.daily == HabitFrequency.daily)
        #expect(HabitFrequency.weekly(targetDays: 3) == HabitFrequency.weekly(targetDays: 3))
        #expect(HabitFrequency.weekly(targetDays: 3) != HabitFrequency.weekly(targetDays: 5))
        #expect(HabitFrequency.daily != HabitFrequency.weekly(targetDays: 7))
    }

    // MARK: - HabitIconCategory

    @Test("HabitIconCategory has all 12 categories")
    func iconCategoryCount() {
        #expect(HabitIconCategory.allCases.count == 12)
    }

    @Test("HabitIconCategory rawValue round-trip")
    func iconCategoryRoundTrip() {
        for category in HabitIconCategory.allCases {
            let restored = HabitIconCategory(rawValue: category.rawValue)
            #expect(restored == category)
        }
    }

    @Test("All icon categories have non-empty iconName")
    func allIconNamesNonEmpty() {
        for category in HabitIconCategory.allCases {
            #expect(!category.iconName.isEmpty)
        }
    }
}
