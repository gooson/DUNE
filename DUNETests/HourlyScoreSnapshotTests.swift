import Foundation
import Testing
@testable import DUNE

@Suite("HourlyScoreSnapshot Tests")
struct HourlyScoreSnapshotTests {

    @Test("hourTruncated truncates to start of hour")
    func hourTruncated() {
        // 2026-03-13 14:37:22 → 2026-03-13 14:00:00
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 3, day: 13,
            hour: 14, minute: 37, second: 22
        )
        let date = calendar.date(from: components)!

        let truncated = HourlyScoreSnapshot.hourTruncated(date)
        let truncatedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: truncated)

        #expect(truncatedComponents.year == 2026)
        #expect(truncatedComponents.month == 3)
        #expect(truncatedComponents.day == 13)
        #expect(truncatedComponents.hour == 14)
        #expect(truncatedComponents.minute == 0)
        #expect(truncatedComponents.second == 0)
    }

    @Test("hourTruncated at exact hour returns same")
    func hourTruncatedExactHour() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 3, day: 13,
            hour: 9, minute: 0, second: 0
        )
        let date = calendar.date(from: components)!

        let truncated = HourlyScoreSnapshot.hourTruncated(date)
        #expect(truncated == date)
    }

    @Test("Init stores all score fields")
    func initStoresFields() {
        let date = Date()
        let snap = HourlyScoreSnapshot(
            date: date,
            conditionScore: 72,
            wellnessScore: 68,
            readinessScore: 81,
            hrvValue: 45.5,
            rhrValue: 58.0,
            sleepScore: 85.0
        )

        #expect(snap.date == date)
        #expect(snap.conditionScore == 72)
        #expect(snap.wellnessScore == 68)
        #expect(snap.readinessScore == 81)
        #expect(snap.hrvValue == 45.5)
        #expect(snap.rhrValue == 58.0)
        #expect(snap.sleepScore == 85.0)
    }

    @Test("Init with nil scores")
    func initWithNilScores() {
        let snap = HourlyScoreSnapshot(date: Date())

        #expect(snap.conditionScore == nil)
        #expect(snap.wellnessScore == nil)
        #expect(snap.readinessScore == nil)
        #expect(snap.hrvValue == nil)
        #expect(snap.rhrValue == nil)
        #expect(snap.sleepScore == nil)
    }
}
