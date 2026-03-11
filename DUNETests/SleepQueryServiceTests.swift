import Testing
import Foundation
@testable import DUNE

@Suite("SleepQueryService interval helpers")
struct SleepQueryServiceTests {

    // MARK: - sleep query window

    @Test("Sleep query window extends beyond noon for late wake stages")
    func sleepQueryWindowExtendsPastNoon() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let referenceDate = try #require(makeDate(2026, 3, 12, 8, 0, calendar: calendar))
        let window = try #require(SleepQueryService.sleepQueryWindow(for: referenceDate, calendar: calendar))
        let lateWakeStageEnd = try #require(makeDate(2026, 3, 12, 12, 25, calendar: calendar))

        #expect(window.primaryEnd == makeDate(2026, 3, 12, 12, 0, calendar: calendar))
        #expect(window.extendedEnd >= lateWakeStageEnd)
    }

    @Test("Late wake continuation keeps post-noon stages from the same session")
    func trimLateWakeContinuationKeepsContiguousStages() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let primaryWindowEnd = try #require(makeDate(2026, 3, 12, 12, 0, calendar: calendar))
        let stages = [
            sleepStage(
                .core,
                start: try #require(makeDate(2026, 3, 12, 8, 14, calendar: calendar)),
                end: try #require(makeDate(2026, 3, 12, 12, 0, calendar: calendar))
            ),
            sleepStage(
                .rem,
                start: try #require(makeDate(2026, 3, 12, 12, 0, calendar: calendar)),
                end: try #require(makeDate(2026, 3, 12, 12, 25, calendar: calendar))
            ),
        ]

        let trimmed = SleepQueryService.trimLateWakeContinuation(
            stages,
            primaryWindowEnd: primaryWindowEnd
        )

        #expect(trimmed.count == 2)
        #expect(trimmed.reduce(0.0) { $0 + $1.duration } / 60.0 == 251)
    }

    @Test("Late wake continuation excludes separated afternoon naps")
    func trimLateWakeContinuationDropsSeparatedNap() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let primaryWindowEnd = try #require(makeDate(2026, 3, 12, 12, 0, calendar: calendar))
        let stages = [
            sleepStage(
                .core,
                start: try #require(makeDate(2026, 3, 12, 9, 0, calendar: calendar)),
                end: try #require(makeDate(2026, 3, 12, 11, 55, calendar: calendar))
            ),
            sleepStage(
                .rem,
                start: try #require(makeDate(2026, 3, 12, 11, 55, calendar: calendar)),
                end: try #require(makeDate(2026, 3, 12, 12, 25, calendar: calendar))
            ),
            sleepStage(
                .core,
                start: try #require(makeDate(2026, 3, 12, 14, 30, calendar: calendar)),
                end: try #require(makeDate(2026, 3, 12, 14, 50, calendar: calendar))
            ),
        ]

        let trimmed = SleepQueryService.trimLateWakeContinuation(
            stages,
            primaryWindowEnd: primaryWindowEnd
        )

        #expect(trimmed.count == 2)
        #expect(trimmed.last?.endDate == makeDate(2026, 3, 12, 12, 25, calendar: calendar))
    }

    // MARK: - mergedIntervals

    @Test("Empty intervals returns empty")
    func mergedIntervalsEmpty() {
        let result = SleepQueryService.mergedIntervals([])
        #expect(result.isEmpty)
    }

    @Test("Single interval returns itself")
    func mergedIntervalsSingle() {
        let a = Date(timeIntervalSinceReferenceDate: 0)
        let b = Date(timeIntervalSinceReferenceDate: 3600)
        let result = SleepQueryService.mergedIntervals([(a, b)])
        #expect(result.count == 1)
        #expect(result[0].0 == a)
        #expect(result[0].1 == b)
    }

    @Test("Non-overlapping intervals stay separate")
    func mergedIntervalsNoOverlap() {
        let a = Date(timeIntervalSinceReferenceDate: 0)
        let b = Date(timeIntervalSinceReferenceDate: 3600)
        let c = Date(timeIntervalSinceReferenceDate: 7200)
        let d = Date(timeIntervalSinceReferenceDate: 10800)
        let result = SleepQueryService.mergedIntervals([(a, b), (c, d)])
        #expect(result.count == 2)
    }

    @Test("Overlapping intervals merge")
    func mergedIntervalsOverlap() {
        let a = Date(timeIntervalSinceReferenceDate: 0)
        let b = Date(timeIntervalSinceReferenceDate: 7200) // 2h
        let c = Date(timeIntervalSinceReferenceDate: 3600) // 1h (overlaps)
        let d = Date(timeIntervalSinceReferenceDate: 10800) // 3h
        let result = SleepQueryService.mergedIntervals([(a, b), (c, d)])
        #expect(result.count == 1)
        #expect(result[0].0 == a)
        #expect(result[0].1 == d)
    }

    @Test("Adjacent intervals merge")
    func mergedIntervalsAdjacent() {
        let a = Date(timeIntervalSinceReferenceDate: 0)
        let b = Date(timeIntervalSinceReferenceDate: 3600)
        let c = Date(timeIntervalSinceReferenceDate: 3600) // exact boundary
        let d = Date(timeIntervalSinceReferenceDate: 7200)
        let result = SleepQueryService.mergedIntervals([(a, b), (c, d)])
        #expect(result.count == 1)
        #expect(result[0].0 == a)
        #expect(result[0].1 == d)
    }

    @Test("Multiple overlapping intervals merge into one")
    func mergedIntervalsMultipleOverlap() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let intervals: [(Date, Date)] = [
            (base.addingTimeInterval(0), base.addingTimeInterval(3600)),      // 0-1h
            (base.addingTimeInterval(1800), base.addingTimeInterval(5400)),   // 0.5-1.5h
            (base.addingTimeInterval(3600), base.addingTimeInterval(7200)),   // 1-2h
            (base.addingTimeInterval(10800), base.addingTimeInterval(14400)), // 3-4h (gap)
        ]
        let result = SleepQueryService.mergedIntervals(intervals)
        #expect(result.count == 2)
        #expect(result[0].0 == base)
        #expect(result[0].1 == base.addingTimeInterval(7200)) // merged 0-2h
        #expect(result[1].0 == base.addingTimeInterval(10800))
    }

    // MARK: - subtractIntervals

    @Test("No subtraction returns original")
    func subtractIntervalsEmpty() {
        let a = Date(timeIntervalSinceReferenceDate: 0)
        let b = Date(timeIntervalSinceReferenceDate: 3600)
        let result = SleepQueryService.subtractIntervals(from: (a, b), subtracting: [])
        #expect(result.count == 1)
        #expect(result[0].0 == a)
        #expect(result[0].1 == b)
    }

    @Test("Full subtraction returns empty")
    func subtractIntervalsFull() {
        let a = Date(timeIntervalSinceReferenceDate: 0)
        let b = Date(timeIntervalSinceReferenceDate: 3600)
        let result = SleepQueryService.subtractIntervals(from: (a, b), subtracting: [(a, b)])
        #expect(result.isEmpty)
    }

    @Test("Partial subtraction from start keeps remainder")
    func subtractIntervalsFromStart() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // interval: 0-6h, subtract: 0-3h → remainder: 3-6h
        let result = SleepQueryService.subtractIntervals(
            from: (base, base.addingTimeInterval(21600)),
            subtracting: [(base, base.addingTimeInterval(10800))]
        )
        #expect(result.count == 1)
        #expect(result[0].0 == base.addingTimeInterval(10800))
        #expect(result[0].1 == base.addingTimeInterval(21600))
    }

    @Test("Partial subtraction from end keeps beginning")
    func subtractIntervalsFromEnd() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // interval: 0-6h, subtract: 3-6h → remainder: 0-3h
        let result = SleepQueryService.subtractIntervals(
            from: (base, base.addingTimeInterval(21600)),
            subtracting: [(base.addingTimeInterval(10800), base.addingTimeInterval(21600))]
        )
        #expect(result.count == 1)
        #expect(result[0].0 == base)
        #expect(result[0].1 == base.addingTimeInterval(10800))
    }

    @Test("Middle subtraction creates two segments")
    func subtractIntervalsMiddle() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // interval: 0-6h, subtract: 2-4h → remainder: 0-2h, 4-6h
        let result = SleepQueryService.subtractIntervals(
            from: (base, base.addingTimeInterval(21600)),
            subtracting: [(base.addingTimeInterval(7200), base.addingTimeInterval(14400))]
        )
        #expect(result.count == 2)
        #expect(result[0].0 == base)
        #expect(result[0].1 == base.addingTimeInterval(7200))
        #expect(result[1].0 == base.addingTimeInterval(14400))
        #expect(result[1].1 == base.addingTimeInterval(21600))
    }

    @Test("Key scenario: Watch covers first half, non-Watch remainder preserved")
    func subtractWatchPartialCoverage() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // iPhone: 11pm-5am (6h) sleep
        // Watch: 11pm-2am (3h) stages
        // After subtract: 2am-5am (3h) of iPhone data preserved
        let elevenPM = base
        let twoPM = base.addingTimeInterval(10800)  // +3h
        let fiveAM = base.addingTimeInterval(21600)  // +6h

        let result = SleepQueryService.subtractIntervals(
            from: (elevenPM, fiveAM),           // iPhone 6h
            subtracting: [(elevenPM, twoPM)]    // Watch 3h coverage
        )
        #expect(result.count == 1)
        let remainderDuration = result[0].1.timeIntervalSince(result[0].0)
        #expect(remainderDuration == 10800) // 3h preserved
    }

    @Test("Non-overlapping subtraction returns original")
    func subtractIntervalsNoOverlap() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // interval: 0-3h, subtract: 4-6h → no change
        let result = SleepQueryService.subtractIntervals(
            from: (base, base.addingTimeInterval(10800)),
            subtracting: [(base.addingTimeInterval(14400), base.addingTimeInterval(21600))]
        )
        #expect(result.count == 1)
        #expect(result[0].0 == base)
        #expect(result[0].1 == base.addingTimeInterval(10800))
    }

    @Test("Superset subtraction returns empty")
    func subtractIntervalsSupersetReturnsEmpty() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // interval: 1-5h, subtract: 0-6h → empty
        let result = SleepQueryService.subtractIntervals(
            from: (base.addingTimeInterval(3600), base.addingTimeInterval(18000)),
            subtracting: [(base, base.addingTimeInterval(21600))]
        )
        #expect(result.isEmpty)
    }

    @Test("Multiple subtractions create multiple gaps")
    func subtractIntervalsMultipleGaps() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        // interval: 0-8h
        // subtract: 1-2h, 4-5h
        // result: 0-1h, 2-4h, 5-8h
        let result = SleepQueryService.subtractIntervals(
            from: (base, base.addingTimeInterval(28800)),
            subtracting: [
                (base.addingTimeInterval(3600), base.addingTimeInterval(7200)),
                (base.addingTimeInterval(14400), base.addingTimeInterval(18000)),
            ]
        )
        #expect(result.count == 3)
        // 0-1h
        #expect(result[0].0 == base)
        #expect(result[0].1 == base.addingTimeInterval(3600))
        // 2-4h
        #expect(result[1].0 == base.addingTimeInterval(7200))
        #expect(result[1].1 == base.addingTimeInterval(14400))
        // 5-8h
        #expect(result[2].0 == base.addingTimeInterval(18000))
        #expect(result[2].1 == base.addingTimeInterval(28800))
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) -> Date? {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))
    }

    private func sleepStage(_ stage: SleepStage.Stage, start: Date, end: Date) -> SleepStage {
        SleepStage(
            stage: stage,
            duration: end.timeIntervalSince(start),
            startDate: start,
            endDate: end
        )
    }
}
