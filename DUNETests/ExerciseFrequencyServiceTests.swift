import Foundation
import Testing
@testable import DUNE

@Suite("ExerciseFrequencyService")
struct ExerciseFrequencyServiceTests {

    private func entry(_ name: String, daysAgo: Int = 0) -> ExerciseFrequencyService.WorkoutEntry {
        .init(
            exerciseName: name,
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        )
    }

    @Test("Empty entries returns empty result")
    func emptyEntries() {
        let result = ExerciseFrequencyService.analyze(from: [])
        #expect(result.isEmpty)
    }

    @Test("Single exercise returns 100% frequency")
    func singleExercise() {
        let entries = [entry("Bench Press"), entry("Bench Press")]
        let result = ExerciseFrequencyService.analyze(from: entries)
        #expect(result.count == 1)
        #expect(result[0].exerciseName == "Bench Press")
        #expect(result[0].count == 2)
        #expect(result[0].percentage == 1.0)
    }

    @Test("Multiple exercises sorted by count descending")
    func multipleExercisesSorted() {
        let entries = [
            entry("Bench Press"), entry("Bench Press"), entry("Bench Press"),
            entry("Squat"), entry("Squat"),
            entry("Deadlift"),
        ]
        let result = ExerciseFrequencyService.analyze(from: entries)
        #expect(result.count == 3)
        #expect(result[0].exerciseName == "Bench Press")
        #expect(result[0].count == 3)
        #expect(result[1].exerciseName == "Squat")
        #expect(result[1].count == 2)
        #expect(result[2].exerciseName == "Deadlift")
        #expect(result[2].count == 1)
    }

    @Test("Percentage sums to approximately 1.0")
    func percentageSums() {
        let entries = [
            entry("A"), entry("A"), entry("A"),
            entry("B"), entry("B"),
            entry("C"),
        ]
        let result = ExerciseFrequencyService.analyze(from: entries)
        let totalPercentage = result.reduce(0.0) { $0 + $1.percentage }
        #expect(abs(totalPercentage - 1.0) < 0.001)
    }

    @Test("Last date is most recent occurrence")
    func lastDateMostRecent() {
        let entries = [
            entry("Bench Press", daysAgo: 5),
            entry("Bench Press", daysAgo: 1),
            entry("Bench Press", daysAgo: 10),
        ]
        let result = ExerciseFrequencyService.analyze(from: entries)
        #expect(result.count == 1)
        // lastDate should be the one from 1 day ago (most recent)
        let daysAgoFromLast = Calendar.current.dateComponents(
            [.day], from: result[0].lastDate!, to: Date()
        ).day ?? 0
        #expect(daysAgoFromLast <= 1)
    }

    @Test("Empty exercise name is filtered out")
    func emptyNameFiltered() {
        let entries = [entry(""), entry("Bench Press")]
        let result = ExerciseFrequencyService.analyze(from: entries)
        #expect(result.count == 1)
        #expect(result[0].exerciseName == "Bench Press")
    }

    @Test("Whitespace-only name is filtered out")
    func whitespaceNameFiltered() {
        let entries = [entry("   "), entry("Bench Press")]
        let result = ExerciseFrequencyService.analyze(from: entries)
        #expect(result.count == 1)
    }
}
