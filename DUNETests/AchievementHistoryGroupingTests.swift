import Foundation
import Testing
@testable import DUNE

@Suite("Achievement history day grouping")
@MainActor
struct AchievementHistoryGroupingTests {
    @Test("Same-day rewards share a day and keep event order")
    func sameDayRewards() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 21)))
        let earlier = try #require(calendar.date(byAdding: .day, value: -1, to: day))
        let events = [
            event(id: "pr", date: day.addingTimeInterval(18 * 3600)),
            event(id: "milestone", date: day.addingTimeInterval(9 * 3600)),
            event(id: "older", date: earlier.addingTimeInterval(12 * 3600))
        ]

        let groups = AchievementHistorySection.dayGroups(in: events)
        #expect(groups.count == 2)
        #expect(groups[0].events.map(\.id) == ["pr", "milestone"])
        #expect(groups[1].events.map(\.id) == ["older"])
        #expect(groups[0].id != groups[1].id)
    }

    private func event(id: String, date: Date) -> WorkoutRewardEvent {
        WorkoutRewardEvent(
            id: id, workoutID: "workout", activityTypeRawValue: "running",
            date: date, kind: .milestone, title: id, detail: id,
            pointsAwarded: 10, levelAfterEvent: nil
        )
    }
}
