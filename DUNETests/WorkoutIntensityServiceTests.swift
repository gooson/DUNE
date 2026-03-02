import Foundation
import Testing
@testable import DUNE

@Suite("WorkoutIntensityService")
struct WorkoutIntensityServiceTests {

    let service = WorkoutIntensityService()

    // MARK: - Helpers

    private func strengthSet(weight: Double, reps: Int, type: SetType = .working) -> IntensitySetInput {
        IntensitySetInput(weight: weight, reps: reps, duration: nil, distance: nil, manualIntensity: nil, setType: type)
    }

    private func bodyweightSet(reps: Int) -> IntensitySetInput {
        IntensitySetInput(weight: nil, reps: reps, duration: nil, distance: nil, manualIntensity: nil, setType: .working)
    }

    private func cardioSet(duration: TimeInterval, distance: Double) -> IntensitySetInput {
        IntensitySetInput(weight: nil, reps: nil, duration: duration, distance: distance, manualIntensity: nil, setType: .working)
    }

    private func flexibilitySet(duration: TimeInterval, intensity: Int) -> IntensitySetInput {
        IntensitySetInput(weight: nil, reps: nil, duration: duration, distance: nil, manualIntensity: intensity, setType: .working)
    }

    private func roundsSet(duration: TimeInterval) -> IntensitySetInput {
        IntensitySetInput(weight: nil, reps: nil, duration: duration, distance: nil, manualIntensity: nil, setType: .working)
    }

    private func session(
        type: ExerciseInputType,
        sets: [IntensitySetInput],
        rpe: Int? = nil,
        daysAgo: Int = 0
    ) -> IntensitySessionInput {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return IntensitySessionInput(date: date, exerciseType: type, sets: sets, rpe: rpe)
    }

    // MARK: - Empty / Insufficient Data

    @Test("Empty sets return nil")
    func emptySetsReturnNil() {
        let current = session(type: .setsRepsWeight, sets: [])
        let result = service.calculateIntensity(current: current, history: [])
        #expect(result == nil)
    }

    @Test("No history and no RPE returns nil for strength")
    func noHistoryNoRPEReturnsNil() {
        let current = session(type: .setsRepsWeight, sets: [strengthSet(weight: 100, reps: 5)])
        let result = service.calculateIntensity(current: current, history: [], estimated1RM: nil)
        #expect(result == nil)
    }

    @Test("No history but RPE available uses RPE fallback")
    func noHistoryWithRPEUsesFallback() {
        let current = session(type: .setsRepsWeight, sets: [strengthSet(weight: 100, reps: 5)], rpe: 7)
        let result = service.calculateIntensity(current: current, history: [], estimated1RM: nil)
        #expect(result != nil)
        #expect(result?.detail.method == .rpeOnly)
        #expect(result?.rawScore == 0.7)
    }

    // MARK: - Strength (setsRepsWeight)

    @Test("Strength: 80% of 1RM produces moderate-hard intensity")
    func strength80Percent1RM() {
        let oneRM = 100.0
        let current = session(type: .setsRepsWeight, sets: [
            strengthSet(weight: 80, reps: 5),
            strengthSet(weight: 80, reps: 5),
        ])
        let history = (1...5).map { i in
            session(type: .setsRepsWeight, sets: [
                strengthSet(weight: 70, reps: 8),
                strengthSet(weight: 75, reps: 6),
            ], daysAgo: i * 2)
        }

        let result = service.calculateIntensity(current: current, history: history, estimated1RM: oneRM)
        #expect(result != nil)
        #expect(result!.rawScore >= 0.4)
        #expect(result!.rawScore <= 0.95)
        #expect(result!.detail.method == .oneRMBased)
        #expect(result!.detail.primarySignal != nil)
    }

    @Test("Strength: 100% of 1RM produces hard-max intensity")
    func strength100Percent1RM() {
        let oneRM = 100.0
        let current = session(type: .setsRepsWeight, sets: [
            strengthSet(weight: 100, reps: 1),
        ])
        let history = (1...3).map { i in
            session(type: .setsRepsWeight, sets: [
                strengthSet(weight: 60, reps: 10),
            ], daysAgo: i * 3)
        }

        let result = service.calculateIntensity(current: current, history: history, estimated1RM: oneRM)
        #expect(result != nil)
        #expect(result!.rawScore >= 0.6)
        #expect(result!.level >= .hard)
    }

    @Test("Strength: warmup sets excluded from primary signal")
    func warmupSetsExcluded() {
        let oneRM = 100.0
        let current = session(type: .setsRepsWeight, sets: [
            strengthSet(weight: 30, reps: 15, type: .warmup),
            strengthSet(weight: 80, reps: 5, type: .working),
        ])

        let result = service.calculateIntensity(current: current, history: [], estimated1RM: oneRM)
        #expect(result != nil)
        // Primary should be based on 80kg (working set), not 30kg (warmup)
        if let primary = result?.detail.primarySignal {
            #expect(primary >= 0.7) // 80/100 = 0.8
        }
    }

    @Test("Strength: higher volume than history increases score")
    func higherVolumeThanHistory() {
        let oneRM = 100.0
        let lightHistory = (1...5).map { i in
            session(type: .setsRepsWeight, sets: [
                strengthSet(weight: 60, reps: 5),
            ], daysAgo: i * 2)
        }
        let heavySession = session(type: .setsRepsWeight, sets: [
            strengthSet(weight: 60, reps: 10),
            strengthSet(weight: 60, reps: 10),
            strengthSet(weight: 60, reps: 10),
        ])

        let result = service.calculateIntensity(current: heavySession, history: lightHistory, estimated1RM: oneRM)
        #expect(result != nil)
        #expect(result!.detail.volumeSignal != nil)
        #expect(result!.detail.volumeSignal! > 0.5) // Should be above average
    }

    // MARK: - Bodyweight (setsReps)

    @Test("Bodyweight: above average reps produces higher intensity")
    func bodyweightAboveAverage() {
        let current = session(type: .setsReps, sets: [
            bodyweightSet(reps: 20),
            bodyweightSet(reps: 18),
        ])
        let history = (1...5).map { i in
            session(type: .setsReps, sets: [
                bodyweightSet(reps: 10),
                bodyweightSet(reps: 10),
            ], daysAgo: i)
        }

        let result = service.calculateIntensity(current: current, history: history)
        #expect(result != nil)
        #expect(result!.detail.method == .repsPercentile)
        #expect(result!.rawScore > 0.5)
    }

    @Test("Bodyweight: empty reps returns nil")
    func bodyweightEmptyReps() {
        let current = session(type: .setsReps, sets: [
            IntensitySetInput(weight: nil, reps: nil, duration: nil, distance: nil, manualIntensity: nil, setType: .working),
        ])
        let result = service.calculateIntensity(current: current, history: [])
        #expect(result == nil)
    }

    // MARK: - Cardio (durationDistance)

    @Test("Cardio: faster pace than history produces higher intensity")
    func cardioFasterPace() {
        let current = session(type: .durationDistance, sets: [
            cardioSet(duration: 1200, distance: 5000), // 4:00/km
        ])
        let history = (1...5).map { i in
            session(type: .durationDistance, sets: [
                cardioSet(duration: 1500, distance: 5000), // 5:00/km (slower)
            ], daysAgo: i * 2)
        }

        let result = service.calculateIntensity(current: current, history: history)
        #expect(result != nil)
        #expect(result!.detail.method == .pacePercentile)
        // Faster pace should yield higher primary signal
        #expect(result!.detail.primarySignal != nil)
        #expect(result!.detail.primarySignal! > 0.5)
    }

    @Test("Cardio: zero distance returns nil or RPE fallback")
    func cardioZeroDistance() {
        let current = session(type: .durationDistance, sets: [
            cardioSet(duration: 1200, distance: 0),
        ])
        let result = service.calculateIntensity(current: current, history: [])
        #expect(result == nil)
    }

    // MARK: - Flexibility (durationIntensity)

    @Test("Flexibility: manual intensity 8/10 produces high score")
    func flexibilityHighIntensity() {
        let current = session(type: .durationIntensity, sets: [
            flexibilitySet(duration: 1800, intensity: 8),
        ])
        let history = (1...3).map { i in
            session(type: .durationIntensity, sets: [
                flexibilitySet(duration: 1200, intensity: 5),
            ], daysAgo: i)
        }

        let result = service.calculateIntensity(current: current, history: history)
        #expect(result != nil)
        #expect(result!.detail.method == .manualIntensity)
        #expect(result!.detail.primarySignal! >= 0.7) // 8/10 = 0.8
    }

    // MARK: - Rounds-Based (HIIT)

    @Test("Rounds: more rounds than history produces higher intensity")
    func roundsAboveAverage() {
        let current = session(type: .roundsBased, sets: [
            roundsSet(duration: 30),
            roundsSet(duration: 30),
            roundsSet(duration: 30),
            roundsSet(duration: 30),
            roundsSet(duration: 30),
        ])
        // oldest-first per Correction #156
        let history = (1...5).reversed().map { i in
            session(type: .roundsBased, sets: [
                roundsSet(duration: 30),
                roundsSet(duration: 30),
                roundsSet(duration: 30),
            ], daysAgo: i)
        }

        let result = service.calculateIntensity(current: current, history: history)
        #expect(result != nil)
        #expect(result!.rawScore > 0.3)
        #expect(result!.detail.method == .roundsPercentile)
    }

    // MARK: - RPE Integration

    @Test("RPE contributes 10% weight to final score")
    func rpeContribution() {
        let oneRM = 100.0
        let setsData = [strengthSet(weight: 80, reps: 5)]
        let history = (1...3).map { i in
            session(type: .setsRepsWeight, sets: [strengthSet(weight: 70, reps: 8)], daysAgo: i)
        }

        let withoutRPE = service.calculateIntensity(
            current: session(type: .setsRepsWeight, sets: setsData),
            history: history,
            estimated1RM: oneRM
        )
        let withHighRPE = service.calculateIntensity(
            current: session(type: .setsRepsWeight, sets: setsData, rpe: 10),
            history: history,
            estimated1RM: oneRM
        )

        #expect(withoutRPE != nil)
        #expect(withHighRPE != nil)
        // With max RPE, score should be slightly higher
        #expect(withHighRPE!.rawScore >= withoutRPE!.rawScore)
    }

    // MARK: - Edge Cases

    @Test("Invalid weight (> 500) is ignored")
    func invalidWeightIgnored() {
        let current = session(type: .setsRepsWeight, sets: [
            strengthSet(weight: 600, reps: 5),
        ])
        let result = service.calculateIntensity(current: current, history: [], estimated1RM: 100)
        // 600kg exceeds limit, so should fallback to nil or RPE
        #expect(result == nil)
    }

    @Test("Invalid RPE (outside 1-10) is ignored")
    func invalidRPEIgnored() {
        let current = session(type: .setsRepsWeight, sets: [strengthSet(weight: 100, reps: 5)], rpe: 15)
        let result = service.calculateIntensity(current: current, history: [], estimated1RM: nil)
        #expect(result == nil) // Invalid RPE, no other signals
    }

    @Test("RPE of 0 is ignored")
    func rpeZeroIgnored() {
        let current = session(type: .setsRepsWeight, sets: [strengthSet(weight: 100, reps: 5)], rpe: 0)
        let result = service.calculateIntensity(current: current, history: [], estimated1RM: nil)
        #expect(result == nil)
    }

    @Test("Raw score is always clamped to 0-1")
    func rawScoreClamped() {
        let oneRM = 50.0 // Unrealistically low
        let current = session(type: .setsRepsWeight, sets: [
            strengthSet(weight: 100, reps: 10), // 200% of 1RM
        ])
        let result = service.calculateIntensity(current: current, history: [], estimated1RM: oneRM)
        #expect(result != nil)
        #expect(result!.rawScore >= 0)
        #expect(result!.rawScore <= 1)
    }

    // MARK: - WorkoutIntensityLevel

    @Test("Level mapping from raw score boundaries")
    func levelMapping() {
        #expect(WorkoutIntensityLevel(rawScore: 0.0) == .veryLight)
        #expect(WorkoutIntensityLevel(rawScore: 0.19) == .veryLight)
        #expect(WorkoutIntensityLevel(rawScore: 0.2) == .light)
        #expect(WorkoutIntensityLevel(rawScore: 0.39) == .light)
        #expect(WorkoutIntensityLevel(rawScore: 0.4) == .moderate)
        #expect(WorkoutIntensityLevel(rawScore: 0.59) == .moderate)
        #expect(WorkoutIntensityLevel(rawScore: 0.6) == .hard)
        #expect(WorkoutIntensityLevel(rawScore: 0.79) == .hard)
        #expect(WorkoutIntensityLevel(rawScore: 0.8) == .maxEffort)
        #expect(WorkoutIntensityLevel(rawScore: 1.0) == .maxEffort)
    }

    @Test("Level from negative score is veryLight")
    func levelFromNegative() {
        #expect(WorkoutIntensityLevel(rawScore: -0.5) == .veryLight)
    }

    @Test("Level from score above 1 is maxEffort")
    func levelFromAboveOne() {
        #expect(WorkoutIntensityLevel(rawScore: 1.5) == .maxEffort)
    }

    // MARK: - Percentile Minimum Count

    @Test("Percentile primary signal is nil with only 1 history session")
    func percentileMinimumCount() {
        let current = session(type: .setsReps, sets: [bodyweightSet(reps: 30)])
        let history = [
            session(type: .setsReps, sets: [bodyweightSet(reps: 20)], daysAgo: 2),
        ]
        let result = service.calculateIntensity(current: current, history: history)
        // With < 2 history sessions, percentile (primarySignal) returns nil
        // but volumeSignal still computed from 1 history session
        #expect(result != nil)
        #expect(result?.detail.primarySignal == nil)
        #expect(result?.detail.volumeSignal != nil)
    }

    @Test("Percentile works with 2+ history sessions")
    func percentileWithEnoughHistory() {
        let current = session(type: .setsReps, sets: [bodyweightSet(reps: 30)])
        let history = [
            session(type: .setsReps, sets: [bodyweightSet(reps: 15)], daysAgo: 4),
            session(type: .setsReps, sets: [bodyweightSet(reps: 20)], daysAgo: 2),
        ]
        let result = service.calculateIntensity(current: current, history: history)
        #expect(result != nil)
        #expect(result!.detail.method == .repsPercentile)
    }

    // MARK: - Multi-Signal Combination

    @Test("All three signals combined correctly")
    func threeSignalsCombined() {
        let oneRM = 100.0
        let current = session(type: .setsRepsWeight, sets: [
            strengthSet(weight: 80, reps: 5),
            strengthSet(weight: 80, reps: 5),
        ], rpe: 8)
        let history = (1...5).map { i in
            session(type: .setsRepsWeight, sets: [
                strengthSet(weight: 80, reps: 5),
                strengthSet(weight: 80, reps: 5),
            ], daysAgo: i)
        }

        let result = service.calculateIntensity(current: current, history: history, estimated1RM: oneRM)
        #expect(result != nil)
        #expect(result!.detail.primarySignal != nil)
        #expect(result!.detail.volumeSignal != nil)
        #expect(result!.detail.rpeSignal != nil)
    }

    // MARK: - suggestEffort

    @Test("suggestEffort: 0.0 raw maps to effort 1")
    func suggestEffortMinimum() {
        let result = service.suggestEffort(autoIntensityRaw: 0.0, recentEfforts: [])
        #expect(result != nil)
        #expect(result!.suggestedEffort == 1)
        #expect(result!.category == .easy)
    }

    @Test("suggestEffort: 1.0 raw maps to effort 10")
    func suggestEffortMaximum() {
        let result = service.suggestEffort(autoIntensityRaw: 1.0, recentEfforts: [])
        #expect(result != nil)
        #expect(result!.suggestedEffort == 10)
        #expect(result!.category == .allOut)
    }

    @Test("suggestEffort: 0.5 raw maps to effort 5-6")
    func suggestEffortMiddle() {
        let result = service.suggestEffort(autoIntensityRaw: 0.5, recentEfforts: [])
        #expect(result != nil)
        #expect(result!.suggestedEffort >= 5)
        #expect(result!.suggestedEffort <= 6)
    }

    @Test("suggestEffort: nil raw with history returns last effort")
    func suggestEffortNilRawWithHistory() {
        let result = service.suggestEffort(autoIntensityRaw: nil, recentEfforts: [7, 6, 8])
        #expect(result != nil)
        #expect(result!.suggestedEffort == 7) // Returns last effort
        #expect(result!.lastEffort == 7)
    }

    @Test("suggestEffort: nil raw without history returns nil")
    func suggestEffortNilRawNoHistory() {
        let result = service.suggestEffort(autoIntensityRaw: nil, recentEfforts: [])
        #expect(result == nil)
    }

    @Test("suggestEffort: history calibration adjusts suggestion upward")
    func suggestEffortCalibrationUp() {
        // User consistently rates 8, auto suggests ~5 (raw=0.5)
        let result = service.suggestEffort(autoIntensityRaw: 0.5, recentEfforts: [8, 8, 8])
        #expect(result != nil)
        // Should be higher than uncalibrated 5-6
        #expect(result!.suggestedEffort >= 6)
    }

    @Test("suggestEffort: history calibration adjusts suggestion downward")
    func suggestEffortCalibrationDown() {
        // User consistently rates 3, auto suggests ~8 (raw=0.8)
        let result = service.suggestEffort(autoIntensityRaw: 0.8, recentEfforts: [3, 3, 3])
        #expect(result != nil)
        // Should be lower than uncalibrated 8
        #expect(result!.suggestedEffort <= 7)
    }

    @Test("suggestEffort: averageEffort computed from valid history")
    func suggestEffortAverageComputed() {
        let result = service.suggestEffort(autoIntensityRaw: 0.5, recentEfforts: [6, 8, 4])
        #expect(result != nil)
        #expect(result!.averageEffort != nil)
        // (6 + 8 + 4) / 3 = 6.0
        #expect(result!.averageEffort! >= 5.9)
        #expect(result!.averageEffort! <= 6.1)
    }

    @Test("suggestEffort: invalid efforts in history are filtered")
    func suggestEffortInvalidHistoryFiltered() {
        let result = service.suggestEffort(autoIntensityRaw: 0.5, recentEfforts: [15, 0, -1, 7])
        #expect(result != nil)
        #expect(result!.lastEffort == 7) // Only valid effort
    }

    @Test("suggestEffort: result clamped to 1-10")
    func suggestEffortClamped() {
        // Edge: raw > 1.0 should be rejected (not finite range)
        let result = service.suggestEffort(autoIntensityRaw: 1.5, recentEfforts: [])
        #expect(result == nil) // 1.5 outside 0...1
    }

    @Test("suggestEffort: NaN raw returns nil")
    func suggestEffortNaN() {
        let result = service.suggestEffort(autoIntensityRaw: .nan, recentEfforts: [5])
        #expect(result == nil)
    }

    // MARK: - EffortCategory

    @Test("EffortCategory: effort 1-3 is easy")
    func effortCategoryEasy() {
        #expect(EffortCategory(effort: 1) == .easy)
        #expect(EffortCategory(effort: 2) == .easy)
        #expect(EffortCategory(effort: 3) == .easy)
    }

    @Test("EffortCategory: effort 4-6 is moderate")
    func effortCategoryModerate() {
        #expect(EffortCategory(effort: 4) == .moderate)
        #expect(EffortCategory(effort: 5) == .moderate)
        #expect(EffortCategory(effort: 6) == .moderate)
    }

    @Test("EffortCategory: effort 7-8 is hard")
    func effortCategoryHard() {
        #expect(EffortCategory(effort: 7) == .hard)
        #expect(EffortCategory(effort: 8) == .hard)
    }

    @Test("EffortCategory: effort 9-10 is allOut")
    func effortCategoryAllOut() {
        #expect(EffortCategory(effort: 9) == .allOut)
        #expect(EffortCategory(effort: 10) == .allOut)
    }

    @Test("EffortCategory: effort 0 or negative is allOut (default)")
    func effortCategoryEdge() {
        // Switch default case handles 0, negative, and > 10
        #expect(EffortCategory(effort: 0) == .allOut)
        #expect(EffortCategory(effort: 11) == .allOut)
    }
}
