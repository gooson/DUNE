import Foundation
import Testing
@testable import DUNE

@Suite("MuscleFatigueState")
struct MuscleFatigueStateTests {

    // MARK: - fatigueLevel

    @Test("fatigueLevel uses compoundScore level when present")
    func fatigueLevelWithCompoundScore() {
        let compound = CompoundFatigueScore(
            muscle: .chest,
            normalizedScore: 0.7,
            level: .highFatigue,
            breakdown: FatigueBreakdown(
                workoutContributions: [],
                baseFatigue: 0.7,
                sleepModifier: 1.0,
                readinessModifier: 1.0,
                effectiveTau: 48.0
            )
        )
        let state = MuscleFatigueState(
            muscle: .chest,
            lastTrainedDate: Date(),
            hoursSinceLastTrained: 12,
            weeklyVolume: 10,
            recoveryPercent: 0.3,
            compoundScore: compound
        )
        #expect(state.fatigueLevel == .highFatigue)
    }

    @Test("fatigueLevel returns noData when lastTrainedDate is nil and no compound")
    func fatigueLevelNoData() {
        let state = MuscleFatigueState(
            muscle: .chest,
            lastTrainedDate: nil,
            hoursSinceLastTrained: nil,
            weeklyVolume: 0,
            recoveryPercent: 1.0,
            compoundScore: nil
        )
        #expect(state.fatigueLevel == .noData)
    }

    @Test("fatigueLevel uses recoveryPercent when no compound and has trained date")
    func fatigueLevelFromRecoveryPercent() {
        let state = MuscleFatigueState(
            muscle: .chest,
            lastTrainedDate: Date(),
            hoursSinceLastTrained: 48,
            weeklyVolume: 5,
            recoveryPercent: 1.0,
            compoundScore: nil
        )
        // 1.0 - 1.0 = 0.0 → FatigueLevel.from(normalizedScore: 0.0) = .fullyRecovered
        #expect(state.fatigueLevel == .fullyRecovered)
    }

    @Test("fatigueLevel maps high fatigue from low recovery percent")
    func fatigueLevelHighFatigue() {
        let state = MuscleFatigueState(
            muscle: .chest,
            lastTrainedDate: Date(),
            hoursSinceLastTrained: 2,
            weeklyVolume: 20,
            recoveryPercent: 0.0,
            compoundScore: nil
        )
        // 1.0 - 0.0 = 1.0 → FatigueLevel.from(normalizedScore: 1.0) = highest fatigue level
        let level = state.fatigueLevel
        #expect(level.rawValue >= 8)
    }

    // MARK: - isRecovered / isOverworked

    @Test("isRecovered is true when fatigue level rawValue <= 3")
    func isRecoveredTrue() {
        let state = MuscleFatigueState(
            muscle: .chest,
            lastTrainedDate: Date(),
            hoursSinceLastTrained: 72,
            weeklyVolume: 3,
            recoveryPercent: 0.85,
            compoundScore: nil
        )
        // recoveryPercent 0.85 → normalizedScore 0.15 → low fatigue → isRecovered
        #expect(state.isRecovered == true)
    }

    @Test("isOverworked is true when fatigue level rawValue >= 8")
    func isOverworkedTrue() {
        let state = MuscleFatigueState(
            muscle: .chest,
            lastTrainedDate: Date(),
            hoursSinceLastTrained: 1,
            weeklyVolume: 30,
            recoveryPercent: 0.0,
            compoundScore: nil
        )
        #expect(state.isOverworked == true)
    }

    // MARK: - nextReadyDate

    @Test("nextReadyDate is nil when lastTrainedDate is nil")
    func nextReadyDateNilWhenNoTraining() {
        let state = MuscleFatigueState(
            muscle: .chest,
            lastTrainedDate: nil,
            hoursSinceLastTrained: nil,
            weeklyVolume: 0,
            recoveryPercent: 1.0,
            compoundScore: nil
        )
        #expect(state.nextReadyDate == nil)
    }

    @Test("nextReadyDate is nil when already fully recovered (readyDate in past)")
    func nextReadyDateNilWhenRecovered() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let state = MuscleFatigueState(
            muscle: .chest, // chest recoveryHours is ~48h
            lastTrainedDate: twoDaysAgo,
            hoursSinceLastTrained: 48,
            weeklyVolume: 5,
            recoveryPercent: 1.0,
            compoundScore: nil
        )
        // readyDate = twoDaysAgo + recoveryHours * 3600 ≈ now or past → nil
        #expect(state.nextReadyDate == nil)
    }

    @Test("nextReadyDate returns future date when recovery pending")
    func nextReadyDateFuture() throws {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let state = MuscleFatigueState(
            muscle: .chest, // chest recoveryHours is ~48h, well above 1h
            lastTrainedDate: oneHourAgo,
            hoursSinceLastTrained: 1,
            weeklyVolume: 10,
            recoveryPercent: 0.1,
            compoundScore: nil
        )
        let readyDate = try #require(state.nextReadyDate)
        #expect(readyDate > Date())
    }
}
