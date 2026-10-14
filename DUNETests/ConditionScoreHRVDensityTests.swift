import Foundation
import Testing
@testable import DUNE

@Suite("Condition score HRV sampling density")
struct ConditionScoreHRVDensityTests {
    private let calculator = CalculateConditionScoreUseCase()
    private let calendar = Calendar.current
    private let evaluationDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 10, day: 14, hour: 18)
    )!

    private func sample(dayOffset: Int, hour: Int, minute: Int = 0, value: Double) -> HRVSample {
        let today = calendar.startOfDay(for: evaluationDate)
        let day = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let date = calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
        return HRVSample(value: value, date: date)
    }

    private func dailyScore(_ samples: [HRVSample]) -> CalculateConditionScoreUseCase.Output {
        calculator.execute(input: .init(
            hrvSamples: samples,
            todayRHR: nil,
            yesterdayRHR: nil,
            evaluationDate: evaluationDate
        ))
    }

    @Test("A more frequent morning source does not drown out the evening signal")
    func mixedCadence() {
        let morning: [Double] = [50, 48, 53, 47, 51, 49, 52]
        let evening: [Double] = [70, 65, 66, 63, 69, 62, 68]
        let balanced = morning.indices.flatMap { day in
            [sample(dayOffset: day, hour: 8, value: morning[day]),
             sample(dayOffset: day, hour: 16, value: evening[day])]
        }
        let morningDense = morning.indices.flatMap { day in
            (0..<6).map { minute in
                sample(dayOffset: day, hour: 8, minute: minute, value: morning[day])
            } + [sample(dayOffset: day, hour: 16, value: evening[day])]
        }

        let balancedScore = dailyScore(balanced).score
        let denseScore = dailyScore(morningDense).score
        #expect(balancedScore != nil && denseScore != nil)
        #expect(abs((balancedScore?.detail?.todayHRV ?? 0) - 60) < 0.001)
        #expect(abs((denseScore?.detail?.todayHRV ?? 0) - 60) < 0.001)
        #expect(balancedScore?.score == denseScore?.score)
    }

    @Test("Duplicate recent samples do not switch the intraday window")
    func intradayThreshold() {
        let history = (1...6).map { day in
            sample(dayOffset: day, hour: 12, value: 50)
        }
        let today = [
            sample(dayOffset: 0, hour: 12, value: 60),
            sample(dayOffset: 0, hour: 13, value: 60),
            sample(dayOffset: 0, hour: 16, value: 50),
            sample(dayOffset: 0, hour: 17, value: 50)
        ]
        let sparseScore = calculator.executeIntraday(input: .init(
            hrvSamples: history + today,
            evaluationDate: evaluationDate
        )).score
        let denseScore = calculator.executeIntraday(input: .init(
            hrvSamples: history + today + [sample(dayOffset: 0, hour: 17, minute: 10, value: 50)],
            evaluationDate: evaluationDate
        )).score

        #expect(sparseScore != nil && denseScore != nil)
        #expect(abs((sparseScore?.detail?.todayHRV ?? 0) - 55) < 0.001)
        #expect(abs((denseScore?.detail?.todayHRV ?? 0) - 55) < 0.001)
        #expect(sparseScore?.score == denseScore?.score)
    }

    @Test("Three observed recent hours use equal hourly weight")
    func intradayRecentHours() {
        let history = (1...6).map { day in
            sample(dayOffset: day, hour: 12, value: 50)
        }
        let today = [
            sample(dayOffset: 0, hour: 10, value: 90),
            sample(dayOffset: 0, hour: 15, value: 40),
            sample(dayOffset: 0, hour: 16, value: 50),
            sample(dayOffset: 0, hour: 17, value: 60)
        ]
        let denseHour = (1...5).map { minute in
            sample(dayOffset: 0, hour: 15, minute: minute, value: 40)
        }

        let sparse = calculator.executeIntraday(input: .init(
            hrvSamples: history + today,
            evaluationDate: evaluationDate
        )).score
        let dense = calculator.executeIntraday(input: .init(
            hrvSamples: history + today + denseHour,
            evaluationDate: evaluationDate
        )).score

        #expect(sparse != nil && dense != nil)
        #expect(abs((sparse?.detail?.todayHRV ?? 0) - 50) < 0.001)
        #expect(abs((dense?.detail?.todayHRV ?? 0) - 50) < 0.001)
        #expect(sparse?.score == dense?.score)
    }

    @Test("Two samples in the same hour do not satisfy the intraday fallback")
    func intradayDuplicateOnlyHour() {
        let history = (1...6).map { day in
            sample(dayOffset: day, hour: 12, value: 50)
        }
        let oneSample = sample(dayOffset: 0, hour: 12, value: 60)
        let duplicate = sample(dayOffset: 0, hour: 12, minute: 10, value: 60)

        let single = calculator.executeIntraday(input: .init(
            hrvSamples: history + [oneSample],
            evaluationDate: evaluationDate
        ))
        let dense = calculator.executeIntraday(input: .init(
            hrvSamples: history + [oneSample, duplicate],
            evaluationDate: evaluationDate
        ))

        #expect(single.score == nil)
        #expect(dense.score == nil)
    }
}
