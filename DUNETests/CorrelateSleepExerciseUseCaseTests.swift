import Testing
@testable import DUNE
import Foundation

@Suite("CorrelateSleepExerciseUseCase")
struct CorrelateSleepExerciseUseCaseTests {

    private let sut = CorrelateSleepExerciseUseCase()
    private let calendar = Calendar.current

    private func date(daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
    }

    private func sleepDay(daysAgo: Int, score: Int, deepRatio: Double = 0.2, efficiency: Double = 90) -> CorrelateSleepExerciseUseCase.Input.SleepDay {
        .init(date: date(daysAgo: daysAgo), score: score, deepRatio: deepRatio, efficiency: efficiency)
    }

    private func exerciseDay(daysAgo: Int, intensity: Double) -> CorrelateSleepExerciseUseCase.Input.ExerciseDay {
        .init(date: date(daysAgo: daysAgo), maxIntensity: intensity)
    }

    // MARK: - Confidence

    @Test("Less than 14 pairs yields low confidence")
    func lowConfidence() {
        let input = CorrelateSleepExerciseUseCase.Input(
            sleepByDate: (0..<10).map { sleepDay(daysAgo: $0, score: 70) },
            exerciseByDate: (1..<11).map { exerciseDay(daysAgo: $0, intensity: 0.5) }
        )
        let result = sut.execute(input: input)
        #expect(result.confidence == .low)
        #expect(result.dataPointCount == 10)
    }

    @Test("14-30 pairs yields medium confidence")
    func mediumConfidence() {
        let input = CorrelateSleepExerciseUseCase.Input(
            sleepByDate: (0..<20).map { sleepDay(daysAgo: $0, score: 70) },
            exerciseByDate: (1..<21).map { exerciseDay(daysAgo: $0, intensity: 0.5) }
        )
        let result = sut.execute(input: input)
        #expect(result.confidence == .medium)
    }

    @Test("More than 30 pairs yields high confidence")
    func highConfidence() {
        let input = CorrelateSleepExerciseUseCase.Input(
            sleepByDate: (0..<35).map { sleepDay(daysAgo: $0, score: 70) },
            exerciseByDate: (1..<36).map { exerciseDay(daysAgo: $0, intensity: 0.5) }
        )
        let result = sut.execute(input: input)
        #expect(result.confidence == .high)
    }

    // MARK: - Intensity band classification

    @Test("No exercise maps to rest band")
    func noExerciseIsRest() {
        let input = CorrelateSleepExerciseUseCase.Input(
            sleepByDate: [sleepDay(daysAgo: 0, score: 70)],
            exerciseByDate: [] // no exercise data
        )
        let result = sut.execute(input: input)
        #expect(result.intensityBreakdown[.rest] != nil)
        #expect(result.intensityBreakdown[.rest]?.sampleCount == 1)
    }

    @Test("Intensity bands are correctly classified")
    func intensityBandClassification() {
        let input = CorrelateSleepExerciseUseCase.Input(
            sleepByDate: [
                sleepDay(daysAgo: 0, score: 70), // maps to exercise day -1
                sleepDay(daysAgo: 1, score: 75), // maps to exercise day -2
                sleepDay(daysAgo: 2, score: 80), // maps to exercise day -3
                sleepDay(daysAgo: 3, score: 60), // maps to exercise day -4 (no exercise = rest)
            ],
            exerciseByDate: [
                exerciseDay(daysAgo: 1, intensity: 0.2),  // light
                exerciseDay(daysAgo: 2, intensity: 0.5),  // moderate
                exerciseDay(daysAgo: 3, intensity: 0.85), // intense
            ]
        )
        let result = sut.execute(input: input)
        #expect(result.intensityBreakdown[.light]?.sampleCount == 1)
        #expect(result.intensityBreakdown[.moderate]?.sampleCount == 1)
        #expect(result.intensityBreakdown[.intense]?.sampleCount == 1)
        #expect(result.intensityBreakdown[.rest]?.sampleCount == 1)
    }

    // MARK: - Stats computation

    @Test("Average score computed correctly per band")
    func averageScorePerBand() {
        let input = CorrelateSleepExerciseUseCase.Input(
            sleepByDate: [
                sleepDay(daysAgo: 0, score: 60),
                sleepDay(daysAgo: 1, score: 80),
            ],
            exerciseByDate: [
                exerciseDay(daysAgo: 1, intensity: 0.5), // moderate
                exerciseDay(daysAgo: 2, intensity: 0.5), // moderate
            ]
        )
        let result = sut.execute(input: input)
        let moderate = result.intensityBreakdown[.moderate]!
        #expect(moderate.avgScore == 70.0) // (60 + 80) / 2
        #expect(moderate.sampleCount == 2)
    }

    // MARK: - Edge cases

    @Test("Empty input returns empty breakdown")
    func emptyInput() {
        let input = CorrelateSleepExerciseUseCase.Input(
            sleepByDate: [],
            exerciseByDate: []
        )
        let result = sut.execute(input: input)
        #expect(result.dataPointCount == 0)
        #expect(result.confidence == .low)
        #expect(result.intensityBreakdown.isEmpty)
    }
}
