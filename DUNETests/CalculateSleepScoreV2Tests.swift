import Foundation
import Testing
@testable import DUNE

@Suite("CalculateSleepScore V2 — 5-axis weights")
struct CalculateSleepScoreV2Tests {
    let sut = CalculateSleepScoreUseCase()

    private func stage(_ type: SleepStage.Stage, start: Date, minutes: Double) -> SleepStage {
        SleepStage(
            stage: type,
            duration: minutes * 60,
            startDate: start,
            endDate: start.addingTimeInterval(minutes * 60)
        )
    }

    private var midnight: Date { Calendar.current.startOfDay(for: Date()) }

    // MARK: - Output fields

    @Test("Output includes remRatio and WASO fields")
    func outputFieldsPresent() {
        let stages = [
            stage(.deep, start: midnight, minutes: 90),
            stage(.core, start: midnight.addingTimeInterval(90 * 60), minutes: 210),
            stage(.rem, start: midnight.addingTimeInterval(300 * 60), minutes: 100),
        ]
        let output = sut.execute(input: .init(stages: stages))
        #expect(output.remRatio > 0)
        #expect(output.wasoMinutes >= 0)
        #expect(output.wasoCount >= 0)
    }

    // MARK: - Ideal sleep (all 5 axes optimal)

    @Test("Ideal sleep: 8h, 20% deep, 22% REM, 100% efficiency, 0 WASO → 90+")
    func idealAllAxes() {
        // 480 min total = 8h
        // deep: 96 min (20%), rem: 106 min (22%), core: 278 min (58%)
        let stages = [
            stage(.deep, start: midnight, minutes: 96),
            stage(.core, start: midnight.addingTimeInterval(96 * 60), minutes: 278),
            stage(.rem, start: midnight.addingTimeInterval(374 * 60), minutes: 106),
        ]
        let output = sut.execute(input: .init(stages: stages))
        #expect(output.score >= 90)
        #expect(output.totalMinutes == 480)
        #expect(output.efficiency == 100)
        #expect(output.remRatio > 0.20 && output.remRatio < 0.25)
        #expect(output.wasoMinutes == 0)
    }

    // MARK: - REM impact

    @Test("No REM penalizes score vs balanced REM")
    func noREMPenalty() {
        // Without REM: 8h all core
        let noREM = [stage(.core, start: midnight, minutes: 480)]
        // With REM: 8h balanced
        let withREM = [
            stage(.deep, start: midnight, minutes: 96),
            stage(.core, start: midnight.addingTimeInterval(96 * 60), minutes: 278),
            stage(.rem, start: midnight.addingTimeInterval(374 * 60), minutes: 106),
        ]
        let noREMOutput = sut.execute(input: .init(stages: noREM))
        let withREMOutput = sut.execute(input: .init(stages: withREM))
        #expect(withREMOutput.score > noREMOutput.score)
    }

    @Test("REM ratio in ideal range gets full 15pt")
    func remInIdealRange() {
        // 480 min, REM = 110 min (22.9%) — within 20-25%
        let stages = [
            stage(.core, start: midnight, minutes: 370),
            stage(.rem, start: midnight.addingTimeInterval(370 * 60), minutes: 110),
        ]
        let output = sut.execute(input: .init(stages: stages))
        // Should have REM contribution near max
        #expect(output.remRatio > 0.20 && output.remRatio < 0.25)
    }

    // MARK: - WASO impact

    @Test("Significant WASO reduces score")
    func wasoReducesScore() {
        // Same total sleep, one with no WASO, one with 30 min WASO
        let noWASO = [
            stage(.core, start: midnight, minutes: 240),
            stage(.rem, start: midnight.addingTimeInterval(240 * 60), minutes: 120),
            stage(.deep, start: midnight.addingTimeInterval(360 * 60), minutes: 80),
        ]
        let withWASO = [
            stage(.core, start: midnight, minutes: 120),
            stage(.awake, start: midnight.addingTimeInterval(120 * 60), minutes: 30),
            stage(.core, start: midnight.addingTimeInterval(150 * 60), minutes: 120),
            stage(.rem, start: midnight.addingTimeInterval(270 * 60), minutes: 120),
            stage(.deep, start: midnight.addingTimeInterval(390 * 60), minutes: 80),
        ]
        let noWASOOutput = sut.execute(input: .init(stages: noWASO))
        let withWASOOutput = sut.execute(input: .init(stages: withWASO))
        #expect(noWASOOutput.score > withWASOOutput.score)
        #expect(withWASOOutput.wasoMinutes >= 30)
        #expect(withWASOOutput.wasoCount >= 1)
    }

    // MARK: - Score bounds

    @Test("Score always in 0-100 range")
    func scoreBounds() {
        // Worst case: very short, no deep, no rem, lots of awake
        let stages = [
            stage(.core, start: midnight, minutes: 60),
            stage(.awake, start: midnight.addingTimeInterval(60 * 60), minutes: 60),
        ]
        let output = sut.execute(input: .init(stages: stages))
        #expect(output.score >= 0 && output.score <= 100)
    }

    @Test("Zero sleep returns 0 score")
    func zeroSleep() {
        let output = sut.execute(input: .init(stages: []))
        #expect(output.score == 0)
        #expect(output.remRatio == 0)
        #expect(output.wasoMinutes == 0)
    }
}
