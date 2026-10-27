import Foundation
import Testing
@testable import DUNE

@Suite("WellnessBodyComparison")
struct WellnessBodyComparisonTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test("Selects the latest measured sample on the target calendar day")
    func selectsTargetDayMeasurement() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let latest = calendar.date(byAdding: .day, value: -3, to: now)!
        let target = calendar.date(byAdding: .day, value: -7, to: latest)!
        let early = calendar.startOfDay(for: target).addingTimeInterval(9 * 3600)
        let late = calendar.startOfDay(for: target).addingTimeInterval(18 * 3600)
        let comparison = WellnessBodyComparison.select(
            current: VitalSample(value: 71.4, date: latest),
            history: [
                .init(value: 70, date: early),
                .init(value: 70.5, date: late),
                .init(value: 75, date: latest)
            ],
            validRange: 0.000001...500,
            now: now,
            calendar: calendar
        )

        #expect(comparison?.currentDate == latest)
        #expect(comparison?.previousDate == late)
        #expect(comparison?.previousValue == 70.5)
        #expect(comparison?.change == 71.4 - 70.5)
    }

    @Test("Body fat change is percentage points and zero is retained")
    func percentagePointsAndZero() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let target = calendar.date(byAdding: .day, value: -7, to: now)!
        let comparison = WellnessBodyComparison.select(
            current: VitalSample(value: 18.5, date: now),
            history: [.init(value: 18.5, date: target)],
            validRange: 0.000001...100,
            now: now,
            calendar: calendar
        )

        #expect(comparison?.change == 0)
        #expect(comparison?.previousDate == target)
    }

    @Test("Missing target day uses the latest earlier actual measurement")
    func missingTargetDayUsesEarlierMeasurement() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: now)!
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: now)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let comparison = WellnessBodyComparison.select(
            current: VitalSample(value: 24, date: now),
            history: [
                .init(value: 23, date: sixDaysAgo),
                .init(value: 22, date: eightDaysAgo),
                .init(value: 24, date: now),
                .init(value: 25, date: tomorrow)
            ],
            validRange: 0.000001...100,
            now: now,
            calendar: calendar
        )

        #expect(comparison?.previousDate == eightDaysAgo)
        #expect(comparison?.previousValue == 22)
        #expect(comparison?.change == 2)
    }

    @Test("Six days ago and same-day samples are too recent for comparison")
    func noSampleAtOrBeforeTargetDay() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: now)!
        let comparison = WellnessBodyComparison.select(
            current: VitalSample(value: 24, date: now),
            history: [
                .init(value: 23, date: sixDaysAgo),
                .init(value: 24, date: now)
            ],
            validRange: 0.000001...100,
            now: now,
            calendar: calendar
        )

        #expect(comparison == nil)
    }

    @Test("Rejects nonfinite, zero, and out-of-range measurements")
    func invalidMeasurements() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let target = calendar.date(byAdding: .day, value: -7, to: now)!
        let invalidValues: [Double] = [0, -.infinity, .infinity, .nan, 101]
        for value in invalidValues {
            let comparison = WellnessBodyComparison.select(
                current: VitalSample(value: 18, date: now),
                history: [.init(value: value, date: target)],
                validRange: 0.000001...100,
                now: now,
                calendar: calendar
            )
            #expect(comparison == nil)
        }
    }

    @Test("An older current measurement anchors the target day")
    func staleLatestMeasurement() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let latest = calendar.date(byAdding: .day, value: -3, to: now)!
        let target = calendar.date(byAdding: .day, value: -7, to: latest)!
        let comparison = WellnessBodyComparison.select(
            current: VitalSample(value: 30, date: latest),
            history: [.init(value: 29, date: target)],
            validRange: 0.000001...300,
            now: now,
            calendar: calendar
        )

        #expect(comparison?.currentDate == latest)
        #expect(comparison?.previousDate == target)
        #expect(comparison?.change == 1)
    }

    @Test("A newer history sample never replaces the displayed current measurement")
    func newerHistoryDoesNotReplaceCurrent() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let displayed = calendar.date(byAdding: .day, value: -3, to: now)!
        let target = calendar.date(byAdding: .day, value: -7, to: displayed)!
        let newer = calendar.date(byAdding: .day, value: -1, to: now)!
        let comparison = WellnessBodyComparison.select(
            current: VitalSample(value: 71, date: displayed),
            history: [.init(value: 70, date: target), .init(value: 80, date: newer)],
            validRange: 0.000001...500,
            now: now,
            calendar: calendar
        )

        #expect(comparison?.currentValue == 71)
        #expect(comparison?.currentDate == displayed)
        #expect(comparison?.previousDate == target)
        #expect(comparison?.change == 1)
    }

    @Test("A missing or invalid displayed current measurement yields no comparison")
    func missingOrInvalidCurrent() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let target = calendar.date(byAdding: .day, value: -7, to: now)!
        let history: [BodyCompositionSample] = [
            .init(value: 70, date: target),
            .init(value: 71, date: now)
        ]

        #expect(WellnessBodyComparison.select(
            current: nil, history: history, validRange: 0.000001...500,
            now: now, calendar: calendar
        ) == nil)
        for value in [0, Double.nan, Double.infinity] {
            #expect(WellnessBodyComparison.select(
                current: VitalSample(value: value, date: now),
                history: history, validRange: 0.000001...500,
                now: now, calendar: calendar
            ) == nil)
        }
    }
}
