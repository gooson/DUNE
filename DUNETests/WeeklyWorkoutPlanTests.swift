import Foundation
import Testing
@testable import DUNE

@Suite("WeeklyWorkoutPlan")
struct WeeklyWorkoutPlanTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Assignment uses a calendar day and does not bleed into adjacent days")
    func dayAssignment() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let midnight = calendar.startOfDay(for: day)
        let id = UUID()
        var plan = WeeklyWorkoutPlan()
        plan.assign(id, to: midnight, calendar: calendar)
        #expect(plan.templateID(on: midnight.addingTimeInterval(3600), calendar: calendar) == id)
        #expect(plan.templateID(on: midnight.addingTimeInterval(86400), calendar: calendar) == nil)
        plan.assign(nil, to: day, calendar: calendar)
        #expect(plan.assignments.isEmpty)
    }

    @Test("Plans retain template references across encoding and replacement")
    func persistence() throws {
        let date = Date()
        let first = UUID()
        let replacement = UUID()
        var plan = WeeklyWorkoutPlan()
        plan.assign(first, to: date)
        plan.assign(replacement, to: date)
        let restored = try JSONDecoder().decode(WeeklyWorkoutPlan.self, from: JSONEncoder().encode(plan))
        #expect(restored.templateID(on: date) == replacement)
        #expect(restored.assignments.count == 1)
    }
    @Test("Changing the display calendar does not hide a saved assignment")
    func calendarPreference() {
        let date = Date()
        var plan = WeeklyWorkoutPlan()
        let id = UUID()
        plan.assign(id, to: date, calendar: calendar)
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        #expect(plan.templateID(on: date, calendar: buddhist) == id)
    }

}
