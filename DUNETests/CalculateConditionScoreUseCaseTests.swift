import Foundation
import Testing
@testable import DUNE

@Suite("CalculateConditionScoreUseCase")
struct CalculateConditionScoreUseCaseTests {
    let sut = CalculateConditionScoreUseCase()
    private let calendar = Calendar.current

    private func makeHRVSamples(_ values: [Double]) -> [HRVSample] {
        values.enumerated().compactMap { index, value in
            guard let date = calendar.date(byAdding: .day, value: -index, to: Date()) else { return nil }
            return HRVSample(value: value, date: date)
        }
    }

    private func makeRHRDailyAverages(_ values: [Double]) -> [CalculateConditionScoreUseCase.Input.RHRDailyAverage] {
        values.enumerated().compactMap { index, value in
            guard let date = calendar.date(byAdding: .day, value: -index, to: Date()) else { return nil }
            return .init(date: date, value: value)
        }
    }

    private func makeTimedHRVSamples(_ entries: [(dayOffset: Int, hour: Int, value: Double)]) -> [HRVSample] {
        let today = calendar.startOfDay(for: Date())
        return entries.compactMap { entry in
            guard let day = calendar.date(byAdding: .day, value: -entry.dayOffset, to: today),
                  let date = calendar.date(byAdding: .hour, value: entry.hour, to: day) else {
                return nil
            }
            return HRVSample(value: entry.value, date: date)
        }
    }

    private func makeTimedRHRDailyAverages(_ entries: [(dayOffset: Int, value: Double)]) -> [CalculateConditionScoreUseCase.Input.RHRDailyAverage] {
        let today = calendar.startOfDay(for: Date())
        return entries.compactMap { entry in
            guard let date = calendar.date(byAdding: .day, value: -entry.dayOffset, to: today) else {
                return nil
            }
            return .init(date: date, value: entry.value)
        }
    }

    private func dateAt(hour: Int) -> Date {
        let now = Date()
        let dayStart = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? now
    }

    @Test("Returns nil score when insufficient days")
    func insufficientDays() {
        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: makeHRVSamples([50, 50, 50]),
            todayRHR: nil,
            yesterdayRHR: nil
        )
        let output = sut.execute(input: input)
        #expect(output.score == nil)
        #expect(!output.baselineStatus.isReady)
    }

    @Test("Returns valid score with 7 days of data")
    func sufficientDays() {
        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: makeHRVSamples([50, 50, 50, 50, 50, 50, 50]),
            todayRHR: nil,
            yesterdayRHR: nil
        )
        let output = sut.execute(input: input)
        #expect(output.score != nil)
        #expect(output.baselineStatus.isReady)
    }

    @Test("Score is clamped to 0-100")
    func scoreClamped() {
        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: makeHRVSamples([200, 10, 10, 10, 10, 10, 10]),
            todayRHR: nil,
            yesterdayRHR: nil
        )
        let output = sut.execute(input: input)
        if let score = output.score {
            #expect(score.score >= 0 && score.score <= 100)
        }
    }

    @Test("Returns nil for zero-value HRV samples")
    func zeroValueSamples() {
        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: makeHRVSamples([0, 0, 0, 0, 0, 0, 0]),
            todayRHR: nil,
            yesterdayRHR: nil
        )
        let output = sut.execute(input: input)
        #expect(output.score == nil)
    }

    @Test("RHR baseline adjustment lowers score when today's RHR is above baseline")
    func rhrBaselinePenalty() {
        let samples = makeHRVSamples([30, 50, 50, 50, 50, 50, 50])
        let withoutRHR = sut.execute(input: .init(
            hrvSamples: samples,
            todayRHR: nil,
            yesterdayRHR: nil
        ))
        let withRHR = sut.execute(input: .init(
            hrvSamples: samples,
            rhrDailyAverages: makeRHRDailyAverages([70, 60, 60, 60, 60, 60, 60, 60]),
            todayRHR: 70,
            yesterdayRHR: 60
        ))

        if let scoreWithout = withoutRHR.score, let scoreWith = withRHR.score {
            #expect(scoreWith.score < scoreWithout.score)
            #expect(scoreWith.detail?.rhrAdjustment ?? 0 < 0)
        }
    }

    @Test("RHR contribution positive when today's RHR is below baseline")
    func rhrContributionPositive() {
        let output = sut.execute(input: .init(
            hrvSamples: makeHRVSamples([60, 50, 50, 50, 50, 50, 50]),
            rhrDailyAverages: makeRHRDailyAverages([54, 60, 60, 60, 60, 60, 60, 60]),
            todayRHR: 54,
            yesterdayRHR: 60
        ))
        let rhr = output.contributions.first { $0.factor == .rhr }
        #expect(rhr?.impact == .positive)
    }

    @Test("RHR contribution negative when today's RHR is above baseline")
    func rhrContributionNegative() {
        let output = sut.execute(input: .init(
            hrvSamples: makeHRVSamples([50, 50, 50, 50, 50, 50, 50]),
            rhrDailyAverages: makeRHRDailyAverages([66, 60, 60, 60, 60, 60, 60, 60]),
            todayRHR: 66,
            yesterdayRHR: 60
        ))
        let rhr = output.contributions.first { $0.factor == .rhr }
        #expect(rhr?.impact == .negative)
    }

    @Test("RHR contribution stays neutral when only historical fallback is available")
    func rhrFallbackContribution() {
        let displayDate = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let output = sut.execute(input: .init(
            hrvSamples: makeHRVSamples([50, 50, 50, 50, 50, 50, 50]),
            todayRHR: nil,
            yesterdayRHR: nil,
            displayRHR: 62,
            displayRHRDate: displayDate
        ))
        let rhr = output.contributions.first { $0.factor == .rhr }
        #expect(rhr?.impact == .neutral)
        #expect(rhr?.detail.contains("latest sample") == true)
    }

    @Test("No RHR contribution without any RHR data")
    func noRhrContributionWithoutData() {
        let output = sut.execute(input: .init(
            hrvSamples: makeHRVSamples([50, 50, 50, 50, 50, 50, 50]),
            todayRHR: nil,
            yesterdayRHR: nil
        ))
        let rhr = output.contributions.first { $0.factor == .rhr }
        #expect(rhr == nil)
    }

    @Test("Detail carries baseline-relative RHR fields when provided")
    func detailCarriesBaselineRHRValues() {
        let output = sut.execute(input: .init(
            hrvSamples: makeHRVSamples([50, 50, 50, 50, 50, 50, 50]),
            rhrDailyAverages: makeRHRDailyAverages([64, 60, 60, 60, 60, 60, 60, 60]),
            todayRHR: 64,
            yesterdayRHR: 60
        ))

        #expect(output.score?.detail?.todayRHR == 64)
        #expect(output.score?.detail?.yesterdayRHR == 60)
        #expect(output.score?.detail?.baselineRHR == 60)
        #expect(output.score?.detail?.rhrDeltaFromBaseline == 4)
        #expect(output.score?.detail?.rhrBaselineDays == 7)
    }

    @Test("Detail carries displayRHR when todayRHR is nil")
    func displayRHRFallback() {
        let rhrDate = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let output = sut.execute(input: .init(
            hrvSamples: makeHRVSamples([50, 50, 50, 50, 50, 50, 50]),
            todayRHR: nil,
            yesterdayRHR: nil,
            displayRHR: 62,
            displayRHRDate: rhrDate
        ))
        #expect(output.score?.detail?.todayRHR == nil)
        #expect(output.score?.detail?.displayRHR == 62)
        #expect(output.score?.detail?.displayRHRDate == rhrDate)
    }

    @Test("Condition score applies time-of-day adjustment for real-time guidance")
    func timeOfDayAdjustmentAffectsScore() {
        let baselineInput = CalculateConditionScoreUseCase.Input(
            hrvSamples: makeHRVSamples([50, 50, 50, 50, 50, 50, 50]),
            todayRHR: nil,
            yesterdayRHR: nil,
            evaluationDate: dateAt(hour: 13)
        )
        let morningInput = CalculateConditionScoreUseCase.Input(
            hrvSamples: makeHRVSamples([50, 50, 50, 50, 50, 50, 50]),
            todayRHR: nil,
            yesterdayRHR: nil,
            evaluationDate: dateAt(hour: 4)
        )
        let eveningInput = CalculateConditionScoreUseCase.Input(
            hrvSamples: makeHRVSamples([50, 50, 50, 50, 50, 50, 50]),
            todayRHR: nil,
            yesterdayRHR: nil,
            evaluationDate: dateAt(hour: 19)
        )

        let baseline = sut.execute(input: baselineInput)
        let morning = sut.execute(input: morningInput)
        let evening = sut.execute(input: eveningInput)

        #expect(baseline.score?.detail?.timeOfDayAdjustment == 0)
        #expect(morning.score?.detail?.timeOfDayAdjustment == 6)
        #expect(evening.score?.detail?.timeOfDayAdjustment == -3)
        #expect((morning.score?.score ?? 0) > (baseline.score?.score ?? 0))
        #expect((evening.score?.score ?? 0) < (baseline.score?.score ?? 0))
        #expect(morning.score?.date == morningInput.evaluationDate)
    }

    @Test("Intraday score expands to a 6h window when the recent 3h window is too sparse")
    func intradayWindowExpansion() {
        let hrvSamples = makeTimedHRVSamples([
            (dayOffset: 0, hour: 0, value: 50),
            (dayOffset: 0, hour: 1, value: 50),
            (dayOffset: 0, hour: 4, value: 80),
            (dayOffset: 1, hour: 12, value: 50),
            (dayOffset: 2, hour: 12, value: 50),
            (dayOffset: 3, hour: 12, value: 50),
            (dayOffset: 4, hour: 12, value: 50),
            (dayOffset: 5, hour: 12, value: 50),
            (dayOffset: 6, hour: 12, value: 50)
        ])
        let evaluationDate = dateAt(hour: 4)

        let output = sut.executeIntraday(input: .init(
            hrvSamples: hrvSamples,
            rhrDailyAverages: makeTimedRHRDailyAverages([
                (dayOffset: 0, value: 60),
                (dayOffset: 1, value: 60),
                (dayOffset: 2, value: 60),
                (dayOffset: 3, value: 60),
                (dayOffset: 4, value: 60),
                (dayOffset: 5, value: 60),
                (dayOffset: 6, value: 60)
            ]),
            evaluationDate: evaluationDate
        ))

        #expect(output.score != nil)
        #expect(abs((output.score?.detail?.todayHRV ?? 0) - 60) < 0.001)
    }

    @Test("Intraday score is less sensitive to stale early spikes than cumulative daily scoring")
    func intradaySmootherThanCumulative() {
        let hrvSamples = makeTimedHRVSamples([
            (dayOffset: 0, hour: 0, value: 110),
            (dayOffset: 0, hour: 1, value: 50),
            (dayOffset: 0, hour: 2, value: 50),
            (dayOffset: 0, hour: 3, value: 50),
            (dayOffset: 0, hour: 4, value: 50),
            (dayOffset: 1, hour: 12, value: 50),
            (dayOffset: 2, hour: 12, value: 50),
            (dayOffset: 3, hour: 12, value: 50),
            (dayOffset: 4, hour: 12, value: 50),
            (dayOffset: 5, hour: 12, value: 50),
            (dayOffset: 6, hour: 12, value: 50)
        ])
        let evaluationDate = dateAt(hour: 4)
        let rhr = makeTimedRHRDailyAverages([
            (dayOffset: 0, value: 60),
            (dayOffset: 1, value: 60),
            (dayOffset: 2, value: 60),
            (dayOffset: 3, value: 60),
            (dayOffset: 4, value: 60),
            (dayOffset: 5, value: 60),
            (dayOffset: 6, value: 60)
        ])

        let cumulative = sut.execute(input: .init(
            hrvSamples: hrvSamples,
            rhrDailyAverages: rhr,
            todayRHR: nil,
            yesterdayRHR: nil,
            evaluationDate: evaluationDate
        ))
        let intraday = sut.executeIntraday(input: .init(
            hrvSamples: hrvSamples,
            rhrDailyAverages: rhr,
            evaluationDate: evaluationDate
        ))

        #expect(cumulative.score != nil)
        #expect(intraday.score != nil)
        #expect((intraday.score?.score ?? 0) < (cumulative.score?.score ?? 0))
        #expect(abs((intraday.score?.detail?.todayHRV ?? 0) - 50) < 0.001)
    }
}
