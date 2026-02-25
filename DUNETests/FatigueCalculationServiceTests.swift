import Foundation
import Testing
@testable import DUNE

@Suite("FatigueCalculationService")
struct FatigueCalculationServiceTests {

    let service = FatigueCalculationService()

    // MARK: - Helpers

    private func snapshot(
        hoursAgo: Double,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup] = [],
        sets: Int = 3,
        totalWeight: Double? = nil,
        totalReps: Int? = nil,
        durationMinutes: Double? = nil,
        distanceKm: Double? = nil,
        exerciseName: String? = nil
    ) -> ExerciseRecordSnapshot {
        ExerciseRecordSnapshot(
            date: Date().addingTimeInterval(-hoursAgo * 3600),
            exerciseName: exerciseName,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            completedSetCount: sets,
            totalWeight: totalWeight,
            totalReps: totalReps,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm
        )
    }

    // MARK: - No Records

    @Test("empty records produce noData level for all muscles")
    func emptyRecords() {
        let scores = service.computeCompoundFatigue(
            for: Array(MuscleGroup.allCases),
            from: [],
            sleepModifier: 1.0,
            readinessModifier: 1.0,
            referenceDate: Date()
        )
        for score in scores {
            #expect(score.level == .noData)
            #expect(score.normalizedScore == 0)
            #expect(score.breakdown.workoutContributions.isEmpty)
        }
    }

    // MARK: - Session Load

    @Test("weight-based session load scales with volume")
    func weightBasedLoad() {
        // 100kg × 25 reps / 70 bodyweight / 100 = 0.357
        let record = snapshot(
            hoursAgo: 0,
            primaryMuscles: [.chest],
            totalWeight: 100,
            totalReps: 25
        )
        let load = service.sessionLoad(from: record)
        #expect(load > 0.3)
        #expect(load < 0.4)
    }

    @Test("cardio session load uses distance × sqrt(duration)")
    func cardioLoad() {
        // 5km in 30min = 5 * sqrt(0.5) / 10 ≈ 0.354
        let record = snapshot(
            hoursAgo: 0,
            primaryMuscles: [.quadriceps],
            sets: 0,
            durationMinutes: 30,
            distanceKm: 5
        )
        let load = service.sessionLoad(from: record)
        #expect(load > 0.3)
        #expect(load < 0.4)
    }

    @Test("long distance produces much higher load than short")
    func longDistanceHigherLoad() {
        let shortRun = snapshot(
            hoursAgo: 0,
            primaryMuscles: [.quadriceps],
            sets: 0,
            durationMinutes: 30,
            distanceKm: 5
        )
        let longRun = snapshot(
            hoursAgo: 0,
            primaryMuscles: [.quadriceps],
            sets: 0,
            durationMinutes: 120,
            distanceKm: 20
        )
        let shortLoad = service.sessionLoad(from: shortRun)
        let longLoad = service.sessionLoad(from: longRun)
        #expect(longLoad > shortLoad * 3)
    }

    @Test("duration-only fallback for cardio without distance")
    func durationOnlyLoad() {
        let record = snapshot(
            hoursAgo: 0,
            primaryMuscles: [.quadriceps],
            sets: 0,
            durationMinutes: 60
        )
        let load = service.sessionLoad(from: record)
        #expect(load == 1.0) // 60 / 60 = 1.0
    }

    @Test("fallback set count load for bodyweight exercises")
    func fallbackSetCountLoad() {
        let record = snapshot(
            hoursAgo: 0,
            primaryMuscles: [.chest],
            sets: 10
        )
        let load = service.sessionLoad(from: record)
        #expect(load == 1.0) // 10 × 0.1
    }

    // MARK: - Exponential Decay

    @Test("recent workout has higher contribution than old workout")
    func recentHigherThanOld() {
        let recentRecords = [
            snapshot(hoursAgo: 1, primaryMuscles: [.chest], sets: 10),
        ]
        let oldRecords = [
            snapshot(hoursAgo: 72, primaryMuscles: [.chest], sets: 10),
        ]

        let recentScores = service.computeCompoundFatigue(
            for: [.chest],
            from: recentRecords,
            sleepModifier: 1.0,
            readinessModifier: 1.0,
            referenceDate: Date()
        )
        let oldScores = service.computeCompoundFatigue(
            for: [.chest],
            from: oldRecords,
            sleepModifier: 1.0,
            readinessModifier: 1.0,
            referenceDate: Date()
        )

        #expect(recentScores[0].normalizedScore > oldScores[0].normalizedScore)
    }

    @Test("cumulative training produces higher fatigue than single session")
    func cumulativeHigherThanSingle() {
        let single = [
            snapshot(hoursAgo: 6, primaryMuscles: [.chest], sets: 10),
        ]
        let cumulative = [
            snapshot(hoursAgo: 6, primaryMuscles: [.chest], sets: 10),
            snapshot(hoursAgo: 30, primaryMuscles: [.chest], sets: 10),
            snapshot(hoursAgo: 54, primaryMuscles: [.chest], sets: 10),
        ]

        let singleScore = service.computeCompoundFatigue(
            for: [.chest], from: single,
            sleepModifier: 1.0, readinessModifier: 1.0, referenceDate: Date()
        )
        let cumulativeScore = service.computeCompoundFatigue(
            for: [.chest], from: cumulative,
            sleepModifier: 1.0, readinessModifier: 1.0, referenceDate: Date()
        )

        #expect(cumulativeScore[0].normalizedScore > singleScore[0].normalizedScore)
    }

    // MARK: - Engagement

    @Test("secondary muscles receive reduced fatigue")
    func secondaryEngagement() {
        let records = [
            snapshot(hoursAgo: 1, primaryMuscles: [.chest], secondaryMuscles: [.triceps], sets: 10),
        ]
        let scores = service.computeCompoundFatigue(
            for: [.chest, .triceps],
            from: records,
            sleepModifier: 1.0,
            readinessModifier: 1.0,
            referenceDate: Date()
        )
        let chestScore = scores.first { $0.muscle == .chest }!
        let tricepsScore = scores.first { $0.muscle == .triceps }!
        #expect(chestScore.normalizedScore > tricepsScore.normalizedScore)
    }

    // MARK: - Recovery Modifiers

    @Test("better sleep modifier produces lower fatigue")
    func sleepModifierEffect() {
        let records = [
            snapshot(hoursAgo: 24, primaryMuscles: [.chest], sets: 15),
        ]

        let poorSleep = service.computeCompoundFatigue(
            for: [.chest], from: records,
            sleepModifier: 0.6, readinessModifier: 1.0, referenceDate: Date()
        )
        let goodSleep = service.computeCompoundFatigue(
            for: [.chest], from: records,
            sleepModifier: 1.2, readinessModifier: 1.0, referenceDate: Date()
        )

        #expect(poorSleep[0].normalizedScore > goodSleep[0].normalizedScore)
    }

    @Test("better readiness modifier produces lower fatigue")
    func readinessModifierEffect() {
        let records = [
            snapshot(hoursAgo: 24, primaryMuscles: [.chest], sets: 15),
        ]

        let poorReadiness = service.computeCompoundFatigue(
            for: [.chest], from: records,
            sleepModifier: 1.0, readinessModifier: 0.7, referenceDate: Date()
        )
        let goodReadiness = service.computeCompoundFatigue(
            for: [.chest], from: records,
            sleepModifier: 1.0, readinessModifier: 1.15, referenceDate: Date()
        )

        #expect(poorReadiness[0].normalizedScore > goodReadiness[0].normalizedScore)
    }

    // MARK: - Breakdown

    @Test("breakdown contains correct number of contributions")
    func breakdownContributions() {
        let records = [
            snapshot(hoursAgo: 6, primaryMuscles: [.chest], sets: 10),
            snapshot(hoursAgo: 30, primaryMuscles: [.chest], sets: 8),
        ]
        let scores = service.computeCompoundFatigue(
            for: [.chest], from: records,
            sleepModifier: 1.0, readinessModifier: 1.0, referenceDate: Date()
        )
        #expect(scores[0].breakdown.workoutContributions.count == 2)
        #expect(scores[0].breakdown.effectiveTau > 0)
    }

    // MARK: - Saturation

    @Test("normalized score is capped at 1.0")
    func normalizedScoreCapped() {
        // Extreme volume to guarantee saturation well above threshold (10 for small muscles)
        // sessionLoad = 500 * 500 / 70 / 100 = 35.7 per session
        let records = (0..<10).map { day in
            snapshot(
                hoursAgo: Double(day * 24),
                primaryMuscles: [.biceps], // small muscle, threshold = 10
                sets: 30,
                totalWeight: 500,
                totalReps: 500
            )
        }
        let scores = service.computeCompoundFatigue(
            for: [.biceps], from: records,
            sleepModifier: 1.0, readinessModifier: 1.0, referenceDate: Date()
        )
        #expect(scores[0].normalizedScore <= 1.0)
        #expect(scores[0].level == .overtrained)
    }

    // MARK: - Edge Cases

    @Test("records older than 14 days are excluded")
    func lookbackWindow() {
        let records = [
            snapshot(hoursAgo: 15 * 24, primaryMuscles: [.chest], sets: 20), // 15 days ago
        ]
        let scores = service.computeCompoundFatigue(
            for: [.chest], from: records,
            sleepModifier: 1.0, readinessModifier: 1.0, referenceDate: Date()
        )
        #expect(scores[0].level == .noData)
        #expect(scores[0].normalizedScore == 0)
    }

    @Test("unrelated muscles produce noData")
    func unrelatedMuscles() {
        let records = [
            snapshot(hoursAgo: 1, primaryMuscles: [.chest], sets: 10),
        ]
        let scores = service.computeCompoundFatigue(
            for: [.quadriceps], from: records,
            sleepModifier: 1.0, readinessModifier: 1.0, referenceDate: Date()
        )
        #expect(scores[0].level == .noData)
    }
}
