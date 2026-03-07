import Foundation
import Testing
@testable import DUNE

@Suite("ActivityPersonalRecord.Kind")
struct ActivityPersonalRecordKindTests {

    @Test("isLowerBetter is true only for fastestPace")
    func isLowerBetter() {
        #expect(ActivityPersonalRecord.Kind.fastestPace.isLowerBetter == true)
        for kind in ActivityPersonalRecord.Kind.allCases where kind != .fastestPace {
            #expect(kind.isLowerBetter == false)
        }
    }

    @Test("init from PersonalRecordType maps all cases correctly")
    func initFromPersonalRecordType() {
        #expect(ActivityPersonalRecord.Kind(personalRecordType: .fastestPace) == .fastestPace)
        #expect(ActivityPersonalRecord.Kind(personalRecordType: .longestDistance) == .longestDistance)
        #expect(ActivityPersonalRecord.Kind(personalRecordType: .highestCalories) == .highestCalories)
        #expect(ActivityPersonalRecord.Kind(personalRecordType: .longestDuration) == .longestDuration)
        #expect(ActivityPersonalRecord.Kind(personalRecordType: .highestElevation) == .highestElevation)
    }

    @Test("sortOrder values are unique across all cases")
    func sortOrderUnique() {
        let orders = ActivityPersonalRecord.Kind.allCases.map(\.sortOrder)
        #expect(Set(orders).count == orders.count)
    }
}
