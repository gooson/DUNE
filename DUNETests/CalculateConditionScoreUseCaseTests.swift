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
}
