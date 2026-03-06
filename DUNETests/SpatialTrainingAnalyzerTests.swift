import Foundation
import Testing
@testable import DUNE

@Suite("SpatialTrainingAnalyzer")
struct SpatialTrainingAnalyzerTests {
    private let analyzer = SpatialTrainingAnalyzer()

    private func workout(
        activityType: WorkoutActivityType,
        type: String? = nil,
        minutes: Double,
        distanceMeters: Double? = nil,
        daysAgo: Int = 0
    ) -> WorkoutSummary {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return WorkoutSummary(
            id: UUID().uuidString,
            type: type ?? activityType.typeName,
            activityType: activityType,
            duration: minutes * 60,
            calories: nil,
            distance: distanceMeters,
            date: date
        )
    }

    @Test("traditional strength workouts use broad fallback muscles")
    func strengthFallbackMuscles() {
        let summary = workout(activityType: .traditionalStrengthTraining, minutes: 48)

        let snapshot = SpatialTrainingAnalyzer.snapshot(from: summary)

        #expect(snapshot != nil)
        #expect(snapshot?.primaryMuscles == [.chest, .back, .quadriceps, .shoulders])
        #expect(snapshot?.secondaryMuscles == [.biceps, .triceps, .core])
        #expect(snapshot?.completedSetCount == 6)
    }

    @Test("distance workouts prefer larger distance-derived load units")
    func distanceWorkoutPseudoLoadUnits() {
        let run = workout(
            activityType: .running,
            minutes: 42,
            distanceMeters: 10_000
        )

        let units = SpatialTrainingAnalyzer.pseudoLoadUnits(for: run)

        #expect(units == 10)
    }

    @Test("summary prioritizes muscles with the highest recent load")
    func featuredMuscleOrdering() {
        let workouts = [
            workout(activityType: .coreTraining, minutes: 36, daysAgo: 0),
            workout(activityType: .coreTraining, minutes: 32, daysAgo: 1),
            workout(activityType: .coreTraining, minutes: 28, daysAgo: 2),
            workout(activityType: .rowing, minutes: 35, daysAgo: 0),
        ]

        let summary = analyzer.buildSummary(
            workouts: workouts,
            latestHeartRateBPM: 118,
            baselineRHR: 56,
            generatedAt: Date()
        )

        #expect(summary.featuredMuscles.first?.muscle == .core)
        #expect(summary.featuredMuscles.first?.weeklyLoadUnits == 14)
        #expect(summary.featuredMuscles.contains { $0.muscle == .back })
    }

    @Test("heart rate orb preserves live value and baseline delta")
    func heartRateOrbValues() {
        let summary = analyzer.buildSummary(
            workouts: [],
            latestHeartRateBPM: 96,
            baselineRHR: 60,
            generatedAt: Date()
        )

        #expect(summary.heartRateOrb.displayBPM == 96)
        #expect(summary.heartRateOrb.deltaFromBaseline == 36)
        #expect(summary.heartRateOrb.isLive == true)
        #expect(summary.hasAnyData == true)
    }

    @Test("empty workouts still expose baseline-only orb state")
    func baselineOnlyState() {
        let summary = analyzer.buildSummary(
            workouts: [],
            latestHeartRateBPM: nil,
            baselineRHR: 58,
            generatedAt: Date()
        )

        #expect(summary.featuredMuscles.isEmpty)
        #expect(summary.heartRateOrb.displayBPM == 58)
        #expect(summary.heartRateOrb.isLive == false)
        #expect(summary.hasAnyData == true)
    }
}
