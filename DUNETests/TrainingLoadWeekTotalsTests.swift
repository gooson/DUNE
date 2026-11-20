import Foundation
import Testing
@testable import DUNE

@Suite("Training load week comparisons")
struct TrainingLoadWeekTotalsTests {
    @Test(arguments: [3, 11])
    func consecutiveCalendarWeeksAcrossDST(month: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: 10)))
        let points = try (-14...1).map { offset in
            let date = try #require(calendar.date(byAdding: .day, value: offset, to: today))
            return TrainingLoadDataPoint(date: date, load: 1, source: nil)
        }
        let totals = try #require(TrainingLoadWeekTotals(data: points, today: today, calendar: calendar))
        #expect(totals.current == 7)
        #expect(totals.previous == 7)
        for (offset, expected) in [(-14, (0.0, 0.0)), (-13, (0, 1)), (-7, (0, 1)), (-6, (1, 0)), (0, (1, 0)), (1, (0, 0))] {
            let single = try #require(TrainingLoadWeekTotals(data: [points[offset + 14]], today: today, calendar: calendar))
            #expect(single.current == expected.0)
            #expect(single.previous == expected.1)
        }
    }
}
