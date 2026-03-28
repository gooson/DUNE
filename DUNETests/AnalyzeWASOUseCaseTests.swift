import Testing
@testable import DUNE
import Foundation

@Suite("AnalyzeWASOUseCase")
struct AnalyzeWASOUseCaseTests {

    private let sut = AnalyzeWASOUseCase()

    private func stage(_ type: SleepStage.Stage, start: Date, minutes: Double) -> SleepStage {
        SleepStage(
            stage: type,
            duration: minutes * 60,
            startDate: start,
            endDate: start.addingTimeInterval(minutes * 60)
        )
    }

    private var midnight: Date {
        Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Edge Cases

    @Test("Empty stages returns nil")
    func emptyStages() {
        let result = sut.execute(stages: [])
        #expect(result == nil)
    }

    @Test("Only awake stages returns nil")
    func onlyAwakeStages() {
        let stages = [stage(.awake, start: midnight, minutes: 60)]
        let result = sut.execute(stages: stages)
        #expect(result == nil)
    }

    // MARK: - No Awakenings

    @Test("Continuous sleep with no awakenings returns score 100")
    func noAwakenings() {
        let stages = [
            stage(.deep, start: midnight, minutes: 120),
            stage(.core, start: midnight.addingTimeInterval(120 * 60), minutes: 180),
            stage(.rem, start: midnight.addingTimeInterval(300 * 60), minutes: 60)
        ]
        let result = sut.execute(stages: stages)!
        #expect(result.awakeningCount == 0)
        #expect(result.totalWASOMinutes == 0)
        #expect(result.score == 100)
    }

    // MARK: - Short Awakenings (< 5 min, filtered)

    @Test("Short awakenings under 5 minutes are ignored")
    func shortAwakeningsFiltered() {
        let stages = [
            stage(.core, start: midnight, minutes: 120),
            stage(.awake, start: midnight.addingTimeInterval(120 * 60), minutes: 3),
            stage(.core, start: midnight.addingTimeInterval(123 * 60), minutes: 120)
        ]
        let result = sut.execute(stages: stages)!
        #expect(result.awakeningCount == 0)
        #expect(result.score == 100)
    }

    // MARK: - Moderate Awakenings

    @Test("10-minute awakening scores around 100")
    func tenMinuteAwakening() {
        let stages = [
            stage(.core, start: midnight, minutes: 120),
            stage(.awake, start: midnight.addingTimeInterval(120 * 60), minutes: 10),
            stage(.core, start: midnight.addingTimeInterval(130 * 60), minutes: 120)
        ]
        let result = sut.execute(stages: stages)!
        #expect(result.awakeningCount == 1)
        #expect(result.totalWASOMinutes == 10)
        #expect(result.score == 100)
    }

    @Test("20-minute awakening scores around 75")
    func twentyMinuteAwakening() {
        let stages = [
            stage(.core, start: midnight, minutes: 120),
            stage(.awake, start: midnight.addingTimeInterval(120 * 60), minutes: 20),
            stage(.core, start: midnight.addingTimeInterval(140 * 60), minutes: 120)
        ]
        let result = sut.execute(stages: stages)!
        #expect(result.awakeningCount == 1)
        #expect(result.totalWASOMinutes == 20)
        #expect(result.score >= 50 && result.score <= 80)
    }

    // MARK: - Poor Sleep

    @Test("30-minute WASO scores around 50")
    func thirtyMinuteWASO() {
        let stages = [
            stage(.core, start: midnight, minutes: 120),
            stage(.awake, start: midnight.addingTimeInterval(120 * 60), minutes: 30),
            stage(.core, start: midnight.addingTimeInterval(150 * 60), minutes: 120)
        ]
        let result = sut.execute(stages: stages)!
        #expect(result.score >= 45 && result.score <= 55)
    }

    @Test("60-minute WASO scores near minimum")
    func sixtyMinuteWASO() {
        let stages = [
            stage(.core, start: midnight, minutes: 120),
            stage(.awake, start: midnight.addingTimeInterval(120 * 60), minutes: 60),
            stage(.core, start: midnight.addingTimeInterval(180 * 60), minutes: 120)
        ]
        let result = sut.execute(stages: stages)!
        #expect(result.score >= 20 && result.score <= 25)
    }

    // MARK: - Multiple Awakenings

    @Test("Multiple awakenings are summed")
    func multipleAwakenings() {
        let stages = [
            stage(.core, start: midnight, minutes: 60),
            stage(.awake, start: midnight.addingTimeInterval(60 * 60), minutes: 10),
            stage(.deep, start: midnight.addingTimeInterval(70 * 60), minutes: 60),
            stage(.awake, start: midnight.addingTimeInterval(130 * 60), minutes: 10),
            stage(.rem, start: midnight.addingTimeInterval(140 * 60), minutes: 60)
        ]
        let result = sut.execute(stages: stages)!
        #expect(result.awakeningCount == 2)
        #expect(result.totalWASOMinutes == 20)
        #expect(result.longestAwakeningMinutes == 10)
    }
}
