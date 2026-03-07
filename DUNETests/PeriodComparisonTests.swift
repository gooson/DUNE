import Foundation
import Testing
@testable import DUNE

@Suite("PeriodComparison")
struct PeriodComparisonTests {

    // MARK: - Helpers

    private func makeSummary(
        duration: TimeInterval = 3600,
        calories: Double = 500,
        sessions: Int = 5,
        activeDays: Int = 3
    ) -> VolumePeriodSummary {
        VolumePeriodSummary(
            period: .week,
            startDate: Date(),
            endDate: Date(),
            totalDuration: duration,
            totalCalories: calories,
            totalSessions: sessions,
            activeDays: activeDays,
            exerciseTypes: [],
            dailyBreakdown: []
        )
    }

    // MARK: - durationChange

    @Test("durationChange is nil when previous is nil")
    func durationChangeNoPrevious() {
        let comparison = PeriodComparison(current: makeSummary(), previous: nil)
        #expect(comparison.durationChange == nil)
    }

    @Test("durationChange is nil when previous duration is 0")
    func durationChangeZeroPrevious() {
        let comparison = PeriodComparison(
            current: makeSummary(duration: 1000),
            previous: makeSummary(duration: 0)
        )
        #expect(comparison.durationChange == nil)
    }

    @Test("durationChange computes 100% increase correctly")
    func durationChangeIncrease() {
        let comparison = PeriodComparison(
            current: makeSummary(duration: 2000),
            previous: makeSummary(duration: 1000)
        )
        #expect(comparison.durationChange == 100.0)
    }

    @Test("durationChange computes 50% decrease correctly")
    func durationChangeDecrease() {
        let comparison = PeriodComparison(
            current: makeSummary(duration: 500),
            previous: makeSummary(duration: 1000)
        )
        #expect(comparison.durationChange == -50.0)
    }

    // MARK: - calorieChange

    @Test("calorieChange is nil when previous calories is 0")
    func calorieChangeZeroPrevious() {
        let comparison = PeriodComparison(
            current: makeSummary(calories: 500),
            previous: makeSummary(calories: 0)
        )
        #expect(comparison.calorieChange == nil)
    }

    @Test("calorieChange computes correctly")
    func calorieChangeNormal() {
        let comparison = PeriodComparison(
            current: makeSummary(calories: 750),
            previous: makeSummary(calories: 500)
        )
        #expect(comparison.calorieChange == 50.0)
    }

    // MARK: - sessionChange

    @Test("sessionChange is nil when previous sessions is 0")
    func sessionChangeZeroPrevious() {
        let comparison = PeriodComparison(
            current: makeSummary(sessions: 5),
            previous: makeSummary(sessions: 0)
        )
        #expect(comparison.sessionChange == nil)
    }

    @Test("sessionChange computes correctly with Int to Double conversion")
    func sessionChangeNormal() {
        let comparison = PeriodComparison(
            current: makeSummary(sessions: 6),
            previous: makeSummary(sessions: 4)
        )
        #expect(comparison.sessionChange == 50.0)
    }

    // MARK: - activeDaysChange

    @Test("activeDaysChange is nil when previous active days is 0")
    func activeDaysChangeZeroPrevious() {
        let comparison = PeriodComparison(
            current: makeSummary(activeDays: 3),
            previous: makeSummary(activeDays: 0)
        )
        #expect(comparison.activeDaysChange == nil)
    }

    // MARK: - DailyVolumePoint

    @Test("DailyVolumePoint totalDuration sums segments")
    func totalDurationSumsSegments() {
        let point = DailyVolumePoint(
            date: Date(),
            segments: [
                DailyVolumePoint.Segment(typeKey: "a", duration: 100),
                DailyVolumePoint.Segment(typeKey: "b", duration: 200),
                DailyVolumePoint.Segment(typeKey: "c", duration: 300)
            ]
        )
        #expect(point.totalDuration == 600)
    }

    @Test("DailyVolumePoint totalDuration is 0 for empty segments")
    func totalDurationEmpty() {
        let point = DailyVolumePoint(date: Date(), segments: [])
        #expect(point.totalDuration == 0)
    }
}
