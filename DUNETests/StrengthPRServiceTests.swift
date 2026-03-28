import Foundation
import Testing
@testable import DUNE

@Suite("StrengthPRService")
struct StrengthPRServiceTests {

    private func entry(_ name: String, weight: Double, daysAgo: Int = 0) -> StrengthPRService.WorkoutEntry {
        .init(
            exerciseName: name,
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
            bestWeight: weight
        )
    }

    private func entryWithSets(
        _ name: String,
        weight: Double,
        sets: [SetSnapshot],
        daysAgo: Int = 0
    ) -> StrengthPRService.WorkoutEntry {
        .init(
            exerciseName: name,
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
            bestWeight: weight,
            sets: sets
        )
    }

    // MARK: - Existing max weight tests

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

    // MARK: - 1RM Estimation Tests

    @Test("1RM estimated from set data using Epley formula")
    func estimated1RMFromSets() {
        let sets = [
            SetSnapshot(weight: 100, reps: 5),
        ]
        let entries = [entryWithSets("Squat", weight: 100, sets: sets)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result.count == 1)
        // Epley: 100 * (1 + 5/30) = 100 * 1.1667 ≈ 116.67
        let est = result[0].estimated1RM
        #expect(est != nil)
        #expect(abs(est! - 116.67) < 0.1)
    }

    @Test("1RM picks best set across session")
    func estimated1RMBestSet() {
        let sets = [
            SetSnapshot(weight: 80, reps: 8),   // 80*(1+8/30) = 101.33
            SetSnapshot(weight: 100, reps: 3),  // 100*(1+3/30) = 110.0
            SetSnapshot(weight: 60, reps: 10),  // 60*(1+10/30) = 80.0
        ]
        let entries = [entryWithSets("Bench Press", weight: 80, sets: sets)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result[0].estimated1RM != nil)
        #expect(abs(result[0].estimated1RM! - 110.0) < 0.1)
    }

    @Test("1RM nil when no set data available")
    func estimated1RMNilWithoutSets() {
        let entries = [entry("Bench Press", weight: 80)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result[0].estimated1RM == nil)
    }

    @Test("1RM skips sets with reps > 10")
    func estimated1RMSkipsHighReps() {
        let sets = [
            SetSnapshot(weight: 50, reps: 15),  // > 10, skipped
        ]
        let entries = [entryWithSets("Lateral Raise", weight: 50, sets: sets)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result[0].estimated1RM == nil)
    }

    @Test("1RM = weight when reps = 1")
    func estimated1RMSingleRep() {
        let sets = [
            SetSnapshot(weight: 150, reps: 1),
        ]
        let entries = [entryWithSets("Deadlift", weight: 150, sets: sets)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(abs(result[0].estimated1RM! - 150.0) < 0.1)
    }

    // MARK: - Rep-Max Tests

    @Test("Rep-max tracks 3RM, 5RM, 10RM")
    func repMaxTracksTargetReps() {
        let sets = [
            SetSnapshot(weight: 100, reps: 3),
            SetSnapshot(weight: 80, reps: 5),
            SetSnapshot(weight: 60, reps: 10),
            SetSnapshot(weight: 50, reps: 8),  // Not tracked (8 not in [3,5,10])
        ]
        let entries = [entryWithSets("Squat", weight: 80, sets: sets)]
        let result = StrengthPRService.extractPRs(from: entries)
        let repMaxes = result[0].repMaxEntries
        #expect(repMaxes.count == 3)
        #expect(repMaxes[0].reps == 3)
        #expect(repMaxes[0].weight == 100)
        #expect(repMaxes[1].reps == 5)
        #expect(repMaxes[1].weight == 80)
        #expect(repMaxes[2].reps == 10)
        #expect(repMaxes[2].weight == 60)
    }

    @Test("Rep-max keeps highest weight for same rep count across sessions")
    func repMaxKeepsHighest() {
        let sets1 = [SetSnapshot(weight: 80, reps: 5)]
        let sets2 = [SetSnapshot(weight: 90, reps: 5)]
        let entries = [
            entryWithSets("Bench Press", weight: 80, sets: sets1, daysAgo: 7),
            entryWithSets("Bench Press", weight: 90, sets: sets2, daysAgo: 1),
        ]
        let result = StrengthPRService.extractPRs(from: entries)
        let fiveRM = result[0].repMaxEntries.first { $0.reps == 5 }
        #expect(fiveRM?.weight == 90)
    }

    @Test("Rep-max empty when no tracked rep counts match")
    func repMaxEmptyNoMatch() {
        let sets = [
            SetSnapshot(weight: 80, reps: 8),
            SetSnapshot(weight: 70, reps: 12),
        ]
        let entries = [entryWithSets("Curl", weight: 75, sets: sets)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result[0].repMaxEntries.isEmpty)
    }

    // MARK: - Volume PR Tests

    @Test("Session volume calculated as sum of weight x reps")
    func sessionVolumeCalculated() {
        let sets = [
            SetSnapshot(weight: 100, reps: 5),   // 500
            SetSnapshot(weight: 100, reps: 5),   // 500
            SetSnapshot(weight: 80, reps: 8),    // 640
        ]
        let entries = [entryWithSets("Squat", weight: 93, sets: sets)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result[0].bestSessionVolume != nil)
        #expect(abs(result[0].bestSessionVolume! - 1640.0) < 0.1)
    }

    @Test("Volume picks best session across multiple sessions")
    func volumeBestSession() {
        let sets1 = [
            SetSnapshot(weight: 100, reps: 3),   // 300
            SetSnapshot(weight: 100, reps: 3),   // 300
        ]
        let sets2 = [
            SetSnapshot(weight: 80, reps: 10),   // 800
            SetSnapshot(weight: 80, reps: 10),   // 800
        ]
        let entries = [
            entryWithSets("Bench Press", weight: 100, sets: sets1, daysAgo: 7),
            entryWithSets("Bench Press", weight: 80, sets: sets2, daysAgo: 1),
        ]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(abs(result[0].bestSessionVolume! - 1600.0) < 0.1)
    }

    @Test("Volume nil when no set data available")
    func volumeNilWithoutSets() {
        let entries = [entry("Bench Press", weight: 80)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(result[0].bestSessionVolume == nil)
    }

    @Test("Volume skips zero-weight sets")
    func volumeSkipsZeroWeight() {
        let sets = [
            SetSnapshot(weight: 0, reps: 10),    // Skipped
            SetSnapshot(weight: 80, reps: 5),    // 400
        ]
        let entries = [entryWithSets("Pull-up", weight: 40, sets: sets)]
        let result = StrengthPRService.extractPRs(from: entries)
        #expect(abs(result[0].bestSessionVolume! - 400.0) < 0.1)
    }
}
