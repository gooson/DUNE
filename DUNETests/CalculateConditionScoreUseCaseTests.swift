import Foundation
import Testing
@testable import DUNE

@Suite("CalculateConditionScoreUseCase")
struct CalculateConditionScoreUseCaseTests {
    let sut = CalculateConditionScoreUseCase()

    @Test("Returns nil score when insufficient days")
    func insufficientDays() {
        let samples = (0..<3).map { day in
            HRVSample(value: 50, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: samples, todayRHR: nil, yesterdayRHR: nil
        )
        let output = sut.execute(input: input)
        #expect(output.score == nil)
        #expect(!output.baselineStatus.isReady)
    }

    @Test("Returns valid score with 7 days of data")
    func sufficientDays() {
        let samples = (0..<7).map { day in
            HRVSample(value: 50, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: samples, todayRHR: nil, yesterdayRHR: nil
        )
        let output = sut.execute(input: input)
        #expect(output.score != nil)
        #expect(output.baselineStatus.isReady)
    }

    @Test("Score is clamped to 0-100")
    func scoreClamped() {
        // Extreme variance: today very high, baseline very low
        var samples = (1..<7).map { day in
            HRVSample(value: 10, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        samples.insert(HRVSample(value: 200, date: Date()), at: 0)

        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: samples, todayRHR: nil, yesterdayRHR: nil
        )
        let output = sut.execute(input: input)
        if let score = output.score {
            #expect(score.score >= 0 && score.score <= 100)
        }
    }

    @Test("Returns nil for zero-value HRV samples")
    func zeroValueSamples() {
        let samples = (0..<7).map { day in
            HRVSample(value: 0, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        let input = CalculateConditionScoreUseCase.Input(
            hrvSamples: samples, todayRHR: nil, yesterdayRHR: nil
        )
        let output = sut.execute(input: input)
        #expect(output.score == nil)
    }

    @Test("RHR correction lowers score when RHR rises and HRV drops")
    func rhrCorrection() {
        // Normal baseline
        var samples = (1..<7).map { day in
            HRVSample(value: 50, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        // Today: lower HRV
        samples.insert(HRVSample(value: 30, date: Date()), at: 0)

        let withoutRHR = sut.execute(input: .init(
            hrvSamples: samples, todayRHR: nil, yesterdayRHR: nil
        ))
        let withRHR = sut.execute(input: .init(
            hrvSamples: samples, todayRHR: 75, yesterdayRHR: 65
        ))

        if let scoreWithout = withoutRHR.score, let scoreWith = withRHR.score {
            #expect(scoreWith.score <= scoreWithout.score)
        }
    }

    // MARK: - Score Contributions

    @Test("Contributions empty when insufficient data")
    func contributionsEmptyInsufficientData() {
        let samples = (0..<3).map { day in
            HRVSample(value: 50, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        let output = sut.execute(input: .init(
            hrvSamples: samples, todayRHR: nil, yesterdayRHR: nil
        ))
        #expect(output.contributions.isEmpty)
    }

    @Test("HRV contribution positive when z-score is high")
    func hrvContributionPositive() {
        var samples = (1..<7).map { day in
            HRVSample(value: 40, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        // Today: significantly higher HRV
        samples.insert(HRVSample(value: 80, date: Date()), at: 0)

        let output = sut.execute(input: .init(
            hrvSamples: samples, todayRHR: nil, yesterdayRHR: nil
        ))
        let hrv = output.contributions.first { $0.factor == .hrv }
        #expect(hrv?.impact == .positive)
    }

    @Test("HRV contribution negative when z-score is low")
    func hrvContributionNegative() {
        var samples = (1..<7).map { day in
            HRVSample(value: 60, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        // Today: significantly lower HRV
        samples.insert(HRVSample(value: 25, date: Date()), at: 0)

        let output = sut.execute(input: .init(
            hrvSamples: samples, todayRHR: nil, yesterdayRHR: nil
        ))
        let hrv = output.contributions.first { $0.factor == .hrv }
        #expect(hrv?.impact == .negative)
    }

    @Test("RHR contribution negative when RHR increases")
    func rhrContributionNegative() {
        let samples = (0..<7).map { day in
            HRVSample(value: 50, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        let output = sut.execute(input: .init(
            hrvSamples: samples, todayRHR: 75, yesterdayRHR: 65
        ))
        let rhr = output.contributions.first { $0.factor == .rhr }
        #expect(rhr?.impact == .negative)
    }

    @Test("RHR contribution positive when RHR decreases")
    func rhrContributionPositive() {
        let samples = (0..<7).map { day in
            HRVSample(value: 50, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        let output = sut.execute(input: .init(
            hrvSamples: samples, todayRHR: 60, yesterdayRHR: 70
        ))
        let rhr = output.contributions.first { $0.factor == .rhr }
        #expect(rhr?.impact == .positive)
    }

    @Test("No RHR contribution without RHR data")
    func noRhrContributionWithoutData() {
        let samples = (0..<7).map { day in
            HRVSample(value: 50, date: Calendar.current.date(byAdding: .day, value: -day, to: Date())!)
        }
        let output = sut.execute(input: .init(
            hrvSamples: samples, todayRHR: nil, yesterdayRHR: nil
        ))
        let rhr = output.contributions.first { $0.factor == .rhr }
        #expect(rhr == nil)
    }
}
