import Foundation
import Testing
@testable import DUNE

@Suite("HealthQuery contracts")
struct HealthQueryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.firstWeekday = 2
        return calendar
    }

    @Test("Calendar day ranges preserve a daylight-saving transition")
    func calendarDayUsesLocalMidnight() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 12)))
        let interval = HealthQueryPeriod.yesterday.interval(endingAt: now, calendar: calendar)
        #expect(interval.duration == 23 * 3_600)
        #expect(calendar.component(.day, from: interval.start) == 8)
        #expect(calendar.component(.day, from: interval.end) == 9)
    }

    @Test("Previous month excludes this month's measurements")
    func previousMonthHasExclusiveEnd() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12)))
        let interval = HealthQueryPeriod.lastMonth.interval(endingAt: now, calendar: calendar)
        #expect(calendar.component(.month, from: interval.start) == 9)
        #expect(calendar.component(.day, from: interval.start) == 1)
        #expect(calendar.component(.month, from: interval.end) == 10)
        #expect(calendar.component(.day, from: interval.end) == 1)
    }

    @Test("Volume uses actual completed set values and rejects invalid numbers")
    func validVolumeAndMissingValues() {
        let valid = HealthQuerySetSnapshot(id: "valid", number: 1, weightKilograms: 80, reps: 8)
        #expect(valid.volumeKilogramRepetitions == 640)
        for weight in [Double.nan, .infinity, -1, 0, 501] {
            #expect(HealthQuerySetSnapshot(id: "bad", number: 1, weightKilograms: weight, reps: 8).volumeKilogramRepetitions == nil)
        }
        #expect(HealthQuerySetSnapshot(id: "missing", number: 1, reps: 8).volumeKilogramRepetitions == nil)
        #expect(HealthQuerySetSnapshot(id: "zero", number: 1, weightKilograms: 80, reps: 0).volumeKilogramRepetitions == nil)
    }

    @Test("Unknown volume stays missing and completed set volumes add once")
    func snapshotVolumeDoesNotInventZero() {
        let date = Date(timeIntervalSince1970: 1_793_361_600)
        let empty = HealthQueryWorkoutSnapshot(id: "app:empty", name: "Bodyweight", date: date)
        #expect(empty.volumeKilogramRepetitions == nil)
        let sets = (1...3).map { HealthQuerySetSnapshot(id: "set-\($0)", number: $0, weightKilograms: 80, reps: 8) }
        let record = HealthQueryWorkoutSnapshot(id: "app:bench", name: "Bench Press", date: date, completedSets: sets)
        #expect(record.volumeKilogramRepetitions == 1_920)
    }
}
