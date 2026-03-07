import Foundation
import Testing
@testable import DUNE

@Suite("InjuryInfo")
struct InjuryInfoTests {

    // MARK: - Helpers

    private func makeInjury(
        bodyPart: BodyPart = .knee,
        bodySide: BodySide? = .left,
        severity: InjurySeverity = .moderate,
        startDate: Date = Date(),
        endDate: Date? = nil,
        memo: String = ""
    ) -> InjuryInfo {
        InjuryInfo(
            id: UUID(),
            bodyPart: bodyPart,
            bodySide: bodySide,
            severity: severity,
            startDate: startDate,
            endDate: endDate,
            memo: memo
        )
    }

    // MARK: - isActive

    @Test("isActive is true when endDate is nil")
    func activeWhenNoEndDate() {
        let injury = makeInjury(endDate: nil)
        #expect(injury.isActive == true)
    }

    @Test("isActive is false when endDate is set")
    func inactiveWhenEndDateSet() {
        let injury = makeInjury(
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date()
        )
        #expect(injury.isActive == false)
    }

    // MARK: - durationDays

    @Test("durationDays is 0 for same-day injury")
    func sameDayDuration() {
        let today = Calendar.current.startOfDay(for: Date())
        let injury = makeInjury(
            bodyPart: .shoulder,
            bodySide: nil,
            severity: .minor,
            startDate: today,
            endDate: today
        )
        #expect(injury.durationDays == 0)
    }

    @Test("durationDays calculates multi-day span correctly")
    func multiDayDuration() throws {
        let start = Calendar.current.startOfDay(for: Date())
        let end = try #require(Calendar.current.date(byAdding: .day, value: 5, to: start))
        let injury = makeInjury(
            bodyPart: .lowerBack,
            bodySide: nil,
            severity: .severe,
            startDate: start,
            endDate: end
        )
        #expect(injury.durationDays == 5)
    }

    @Test("durationDays for active injury counts days since start")
    func activeInjuryDuration() throws {
        let threeDaysAgo = try #require(Calendar.current.date(
            byAdding: .day, value: -3,
            to: Calendar.current.startOfDay(for: Date())
        ))
        let injury = makeInjury(
            bodyPart: .ankle,
            bodySide: .right,
            startDate: threeDaysAgo,
            endDate: nil
        )
        #expect(injury.durationDays == 3)
    }

    // MARK: - affectedMuscleGroups

    @Test("affectedMuscleGroups delegates to bodyPart")
    func affectedMuscleGroupsDelegation() {
        let injury = makeInjury(bodyPart: .chest, bodySide: nil, severity: .minor)
        #expect(injury.affectedMuscleGroups == injury.bodyPart.affectedMuscleGroups)
    }
}
