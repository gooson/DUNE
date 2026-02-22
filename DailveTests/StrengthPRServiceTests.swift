import Foundation
import Testing
@testable import Dailve

@Suite("StrengthPRService")
struct StrengthPRServiceTests {

    private func entry(_ name: String, weight: Double, daysAgo: Int = 0) -> StrengthPRService.WorkoutEntry {
        .init(
            exerciseName: name,
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
            maxWeight: weight
        )
    }

    @Test("Empty entries returns empty PRs")
    func emptyEntries() {
        let result = StrengthPRService.extractPRs(from: [])
        #expect(result.isEmpty)
    }

    @Test("Single exercise returns single PR")
    func singleExercise() {
        let entries = [entry("Bench Press", weight: 80)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result.count == 1)
        #expect(result[0].exerciseName == "Bench Press")
        #expect(result[0].maxWeight == 80)
    }

    @Test("Multiple sessions keep highest weight")
    func multipleSessionsHighest() {
        let entries = [
            entry("Bench Press", weight: 70, daysAgo: 10),
            entry("Bench Press", weight: 90, daysAgo: 5),
            entry("Bench Press", weight: 80, daysAgo: 1),
        ]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result.count == 1)
        #expect(result[0].maxWeight == 90)
    }

    @Test("Multiple exercises sorted by weight descending")
    func multipleExercisesSorted() {
        let entries = [
            entry("Bench Press", weight: 80),
            entry("Squat", weight: 120),
            entry("Deadlift", weight: 150),
        ]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result.count == 3)
        #expect(result[0].exerciseName == "Deadlift")
        #expect(result[1].exerciseName == "Squat")
        #expect(result[2].exerciseName == "Bench Press")
    }

    @Test("Recent flag set for last 7 days")
    func recentFlag() {
        let ref = Date()
        let entries = [
            entry("Bench Press", weight: 80, daysAgo: 3),
            entry("Squat", weight: 100, daysAgo: 10),
        ]
        let result = StrengthPRService.extractPRs(from: entries, referenceDate: ref)
        let bench = result.first { $0.exerciseName == "Bench Press" }
        let squat = result.first { $0.exerciseName == "Squat" }
        #expect(bench?.isRecent == true)
        #expect(squat?.isRecent == false)
    }

    @Test("Zero weight entries are filtered out")
    func zeroWeightFiltered() {
        let entries = [entry("Bench Press", weight: 0)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result.isEmpty)
    }

    @Test("Weight above 500 is filtered out")
    func excessiveWeightFiltered() {
        let entries = [entry("Bench Press", weight: 600)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result.isEmpty)
    }

    @Test("Empty exercise name is filtered out")
    func emptyNameFiltered() {
        let entries = [entry("", weight: 80)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result.isEmpty)
    }

    @Test("NaN weight is filtered out")
    func nanWeightFiltered() {
        let entries = [entry("Bench Press", weight: Double.nan)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result.isEmpty)
    }
}
