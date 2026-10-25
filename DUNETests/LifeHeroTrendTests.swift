import Foundation
import Testing
@testable import DUNE

@Suite("Life hero completion trend")
struct LifeHeroTrendTests {
    private let calendar = Calendar.current

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day))!
    }

    private func habit(id: UUID, created: Int, goal: Double = 1, auto: Bool = false) -> LifeHeroHabitSnapshot {
        LifeHeroHabitSnapshot(
            analyticsHabit: HabitSnapshot(
                id: id,
                name: "Test",
                goalValue: goal,
                frequencyTypeRaw: "daily",
                weeklyTargetDays: 7
            ),
            createdAt: date(created),
            isAutoLinked: auto
        )
    }

    private func log(id: UUID, day: Int, value: Double = 1, memo: String? = nil, auto: Bool = false) -> LifeHeroLogSnapshot {
        LifeHeroLogSnapshot(
            analyticsLog: HabitLogSnapshot(habitID: id, date: date(day), value: value, memo: memo),
            isAutoCompleted: auto
        )
    }

    @Test("Counts completed manual habit days once and excludes cycle actions and auto records")
    func manualCompletionSemantics() {
        let manualID = UUID()
        let autoID = UUID()
        let points = LifeHeroTrend.points(
            habits: [habit(id: manualID, created: 21, goal: 2), habit(id: autoID, created: 19, auto: true)],
            logs: [
                log(id: manualID, day: 20, value: 2), // Before this habit existed.
                log(id: manualID, day: 21, value: 1),
                log(id: manualID, day: 21, value: 1),
                log(id: manualID, day: 21, value: 2), // Duplicate completion on the same day.
                log(id: manualID, day: 22, value: 2, memo: "[dune-life-cycle-skip]"),
                log(id: manualID, day: 23, value: 2, memo: "[dune-life-cycle-snooze]"),
                log(id: manualID, day: 24, value: 2, auto: true),
                log(id: autoID, day: 25, value: 1),
                log(id: manualID, day: 26, value: 2),
                log(id: manualID, day: 27, value: 2) // Future record.
            ],
            referenceDate: date(25),
            calendar: calendar
        )

        #expect(points.map(\.date) == (19...25).map { date($0) })
        #expect(points.map(\.value) == [nil, nil, 1, 0, 0, 0, 0])
    }

    @Test("All dates wait when no current manual completion record exists")
    func noManualRecords() {
        let manualID = UUID()
        let autoID = UUID()
        let points = LifeHeroTrend.points(
            habits: [habit(id: manualID, created: 24), habit(id: autoID, created: 20, auto: true)],
            logs: [log(id: autoID, day: 24), log(id: manualID, day: 25, auto: true)],
            referenceDate: date(25),
            calendar: calendar
        )

        #expect(points.count == 7)
        #expect(points.allSatisfy { $0.value == nil })
    }
}
