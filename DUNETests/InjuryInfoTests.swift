import Foundation
import Testing
@testable import DUNE

@Suite("InjuryInfo")
struct InjuryInfoTests {

    // MARK: - isActive

    @Test("isActive is true when endDate is nil")
    func activeWhenNoEndDate() {
        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .knee,
            bodySide: .left,
            severity: .moderate,
            startDate: Date(),
            endDate: nil,
            memo: ""
        )
        #expect(injury.isActive == true)
    }

    @Test("isActive is false when endDate is set")
    func inactiveWhenEndDateSet() {
        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .knee,
            bodySide: .left,
            severity: .moderate,
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date(),
            memo: ""
        )
        #expect(injury.isActive == false)
    }

    // MARK: - durationDays

    @Test("durationDays is 0 for same-day injury")
    func sameDayDuration() {
        let today = Calendar.current.startOfDay(for: Date())
        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .shoulder,
            bodySide: nil,
            severity: .minor,
            startDate: today,
            endDate: today,
            memo: ""
        )
        #expect(injury.durationDays == 0)
    }

    @Test("durationDays calculates multi-day span correctly")
    func multiDayDuration() {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 5, to: start)!
        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .lowerBack,
            bodySide: nil,
            severity: .severe,
            startDate: start,
            endDate: end,
            memo: ""
        )
        #expect(injury.durationDays == 5)
    }

    @Test("durationDays for active injury counts days since start")
    func activeInjuryDuration() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Calendar.current.startOfDay(for: Date()))!
        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .ankle,
            bodySide: .right,
            severity: .moderate,
            startDate: threeDaysAgo,
            endDate: nil,
            memo: ""
        )
        #expect(injury.durationDays >= 3)
    }

    // MARK: - affectedMuscleGroups

    @Test("affectedMuscleGroups delegates to bodyPart")
    func affectedMuscleGroupsDelegation() {
        let injury = InjuryInfo(
            id: UUID(),
            bodyPart: .chest,
            bodySide: nil,
            severity: .minor,
            startDate: Date(),
            endDate: nil,
            memo: ""
        )
        #expect(injury.affectedMuscleGroups == injury.bodyPart.affectedMuscleGroups)
    }
}
