import Foundation
import Testing
@testable import DUNE

@Suite("LocalTimePresentation")
@MainActor
struct LocalTimePresentationTests {
    private func calendar(_ zone: String = "Asia/Seoul") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ hour: Int, minute: Int = 0, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: hour, minute: minute))!
    }

    @Test("Morning greetings are limited to 06:00–09:59", arguments: Array(0...23))
    func morningWindow(hour: Int) {
        #expect((LocalDayPeriod(hour: hour) == .morning) == (6..<10).contains(hour))
        let hero = CoachingEngine().generateAdaptiveHeroMessage(
            hour: hour, conditionScore: ConditionScore(score: 95, date: Date()),
            sleepDebtMinutes: nil, todayWorkoutDone: false
        )
        #expect((hero.message == String(localized: "Good morning! Great condition for a workout today"))
            == (6..<10).contains(hour))
    }

    @Test("The same instant follows the device time zone")
    func localTimeZones() {
        let instant = date(0, calendar: calendar())
        #expect(LocalDayPeriod(date: instant, calendar: calendar()) == .night)
        #expect(LocalDayPeriod(date: instant, calendar: calendar("America/Los_Angeles")) == .morning)
        #expect(LocalDayPeriod(date: instant, calendar: calendar("UTC")) == .daytime)
    }

    @Test("Night access does not consume the morning; morning is shown once per local day")
    func briefingLifecycle() throws {
        let suite = "LocalTimePresentation-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let calendar = calendar()
        let midnight = date(0, calendar: calendar)
        #expect(!MorningBriefingViewModel.shouldShowBriefing(now: midnight, calendar: calendar, defaults: defaults))
        MorningBriefingViewModel.markBriefingShown(now: midnight, calendar: calendar, defaults: defaults)
        let morning = date(6, calendar: calendar)
        #expect(MorningBriefingViewModel.shouldShowBriefing(now: morning, calendar: calendar, defaults: defaults))
        MorningBriefingViewModel.markBriefingShown(now: morning, calendar: calendar, defaults: defaults)
        #expect(!MorningBriefingViewModel.shouldShowBriefing(now: morning, calendar: calendar, defaults: defaults))
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: morning))
        #expect(MorningBriefingViewModel.shouldShowBriefing(now: tomorrow, calendar: calendar, defaults: defaults))
    }

    @Test("09:59 is morning; 10:00 and 11:59 are not")
    func briefingBoundary() throws {
        let suite = "LocalTimePresentation-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let calendar = calendar()
        #expect(MorningBriefingViewModel.shouldShowBriefing(now: date(9, minute: 59, calendar: calendar), calendar: calendar, defaults: defaults))
        #expect(!MorningBriefingViewModel.shouldShowBriefing(now: date(10, calendar: calendar), calendar: calendar, defaults: defaults))
        #expect(!MorningBriefingViewModel.shouldShowBriefing(now: date(11, minute: 59, calendar: calendar), calendar: calendar, defaults: defaults))
    }

    @Test("Night insights recommend rest even with a high condition score", arguments: [0, 5, 22, 23])
    func nightInsight(hour: Int) {
        for status in [ConditionScore.Status.excellent, .good, .fair, .tired, .warning] {
            #expect(ConditionInsightGuidance.message(status: status, period: LocalDayPeriod(hour: hour))
                == String(localized: "Wind down for a restful night"))
        }
        let message = CoachingEngine().generateAdaptiveHeroMessage(
            hour: hour, conditionScore: ConditionScore(score: 95, date: Date()),
            sleepDebtMinutes: nil, todayWorkoutDone: false
        )
        #expect(!message.message.contains("Good morning"))
    }
}
