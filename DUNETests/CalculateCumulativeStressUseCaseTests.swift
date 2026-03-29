import Foundation
import Testing
@testable import DUNE

@Suite("CalculateCumulativeStressUseCase")
struct CalculateCumulativeStressUseCaseTests {
    let sut = CalculateCumulativeStressUseCase()

    // MARK: - Minimum Data

    @Test("Returns nil when fewer than 7 daily averages")
    func insufficientData() {
        let averages = (0..<6).map { i in
            CalculateCumulativeStressUseCase.Input.DailyAverage(
                date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                value: 50.0
            )
        }
        let input = CalculateCumulativeStressUseCase.Input(hrvDailyAverages: averages)
        #expect(sut.execute(input: input) == nil)
    }

    @Test("Returns score with exactly 7 daily averages")
    func minimumData() {
        let averages = (0..<7).map { i in
            CalculateCumulativeStressUseCase.Input.DailyAverage(
                date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                value: 50.0
            )
        }
        let input = CalculateCumulativeStressUseCase.Input(hrvDailyAverages: averages)
        let result = sut.execute(input: input)
        #expect(result != nil)
    }

    // MARK: - Low Stress

    @Test("Consistent HRV + regular sleep + balanced load → low stress")
    func lowStress() {
        // Very consistent HRV (CV ≈ 0)
        let averages = (0..<14).map { i in
            CalculateCumulativeStressUseCase.Input.DailyAverage(
                date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                value: 50.0
            )
        }

        let regularity = SleepRegularityIndex(
            score: 90,
            bedtimeStdDevMinutes: 15,
            wakeTimeStdDevMinutes: 12,
            averageBedtime: DateComponents(hour: 23, minute: 0),
            averageWakeTime: DateComponents(hour: 7, minute: 0),
            dataPointCount: 14,
            confidence: .high
        )

        let training = CalculateCumulativeStressUseCase.Input.WeeklyTrainingDurations(
            acuteMinutes: 200,
            chronicWeeklyMinutes: 200
        )

        let input = CalculateCumulativeStressUseCase.Input(
            hrvDailyAverages: averages,
            sleepRegularity: regularity,
            weeklyTrainingDurations: training
        )

        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.score < 30, "Expected low stress, got \(result!.score)")
        #expect(result!.level == .low)
    }

    // MARK: - High Stress

    @Test("Variable HRV + irregular sleep + overload → high stress")
    func highStress() {
        // Very variable HRV (CV ≈ 0.5)
        let averages = (0..<14).map { i in
            CalculateCumulativeStressUseCase.Input.DailyAverage(
                date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                value: i.isMultiple(of: 2) ? 80.0 : 20.0
            )
        }

        let regularity = SleepRegularityIndex(
            score: 30,
            bedtimeStdDevMinutes: 90,
            wakeTimeStdDevMinutes: 75,
            averageBedtime: DateComponents(hour: 1, minute: 0),
            averageWakeTime: DateComponents(hour: 8, minute: 0),
            dataPointCount: 14,
            confidence: .high
        )

        let training = CalculateCumulativeStressUseCase.Input.WeeklyTrainingDurations(
            acuteMinutes: 500,
            chronicWeeklyMinutes: 200
        )

        let input = CalculateCumulativeStressUseCase.Input(
            hrvDailyAverages: averages,
            sleepRegularity: regularity,
            weeklyTrainingDurations: training
        )

        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.score > 55, "Expected elevated/high stress, got \(result!.score)")
        #expect(result!.level == .elevated || result!.level == .high)
    }

    // MARK: - Contributions

    @Test("Contributions count matches available components")
    func contributionsCount() {
        let averages = (0..<10).map { i in
            CalculateCumulativeStressUseCase.Input.DailyAverage(
                date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                value: 50.0
            )
        }

        // HRV only
        let inputHRVOnly = CalculateCumulativeStressUseCase.Input(hrvDailyAverages: averages)
        let resultHRV = sut.execute(input: inputHRVOnly)
        #expect(resultHRV?.contributions.count == 1)

        // HRV + sleep
        let regularity = SleepRegularityIndex(
            score: 70,
            bedtimeStdDevMinutes: 30,
            wakeTimeStdDevMinutes: 25,
            averageBedtime: DateComponents(hour: 23, minute: 30),
            averageWakeTime: DateComponents(hour: 7, minute: 0),
            dataPointCount: 10,
            confidence: .medium
        )
        let inputWithSleep = CalculateCumulativeStressUseCase.Input(
            hrvDailyAverages: averages,
            sleepRegularity: regularity
        )
        let resultSleep = sut.execute(input: inputWithSleep)
        #expect(resultSleep?.contributions.count == 2)
    }

    // MARK: - Level Classification

    @Test("Level classification boundaries")
    func levelBoundaries() {
        #expect(CumulativeStressScore.Level.from(score: 0) == .low)
        #expect(CumulativeStressScore.Level.from(score: 29) == .low)
        #expect(CumulativeStressScore.Level.from(score: 30) == .moderate)
        #expect(CumulativeStressScore.Level.from(score: 54) == .moderate)
        #expect(CumulativeStressScore.Level.from(score: 55) == .elevated)
        #expect(CumulativeStressScore.Level.from(score: 74) == .elevated)
        #expect(CumulativeStressScore.Level.from(score: 75) == .high)
        #expect(CumulativeStressScore.Level.from(score: 100) == .high)
    }

    // MARK: - Edge Cases

    @Test("Zero HRV values are filtered out")
    func zeroHRVFiltered() {
        var averages = (0..<7).map { i in
            CalculateCumulativeStressUseCase.Input.DailyAverage(
                date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                value: 50.0
            )
        }
        // Add zero values
        averages.append(contentsOf: (7..<10).map { i in
            CalculateCumulativeStressUseCase.Input.DailyAverage(
                date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                value: 0
            )
        })

        let input = CalculateCumulativeStressUseCase.Input(hrvDailyAverages: averages)
        let result = sut.execute(input: input)
        #expect(result != nil) // 7 valid values should be enough
    }

    @Test("Score is always clamped to 0-100")
    func scoreClamped() {
        let averages = (0..<14).map { i in
            CalculateCumulativeStressUseCase.Input.DailyAverage(
                date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                value: Double(i * 100) // extreme variation
            )
        }
        let input = CalculateCumulativeStressUseCase.Input(hrvDailyAverages: averages)
        let result = sut.execute(input: input)
        #expect(result != nil)
        #expect(result!.score >= 0)
        #expect(result!.score <= 100)
    }
}
