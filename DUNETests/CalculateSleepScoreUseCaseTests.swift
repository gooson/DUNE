import Foundation
import Testing
@testable import DUNE

@Suite("CalculateSleepScoreUseCase")
struct CalculateSleepScoreUseCaseTests {
    let sut = CalculateSleepScoreUseCase()

    @Test("Returns zero for empty stages")
    func emptyStages() {
        let output = sut.execute(input: .init(stages: []))
        #expect(output.score == 0)
        #expect(output.totalMinutes == 0)
        #expect(output.efficiency == 0)
    }

    @Test("Ideal sleep returns high score")
    func idealSleep() {
        let now = Date()
        let stages = [
            SleepStage(stage: .deep, duration: 90 * 60, startDate: now, endDate: now.addingTimeInterval(90 * 60)),
            SleepStage(stage: .core, duration: 240 * 60, startDate: now, endDate: now.addingTimeInterval(240 * 60)),
            SleepStage(stage: .rem, duration: 120 * 60, startDate: now, endDate: now.addingTimeInterval(120 * 60)),
        ]
        let output = sut.execute(input: .init(stages: stages))
        // 7.5 hours, good deep ratio, 100% efficiency
        #expect(output.score >= 70)
        #expect(output.totalMinutes == 450)
        #expect(output.efficiency == 100)
    }

    @Test("Awake time reduces efficiency")
    func awakeReducesEfficiency() {
        let now = Date()
        let stages = [
            SleepStage(stage: .core, duration: 360 * 60, startDate: now, endDate: now.addingTimeInterval(360 * 60)),
            SleepStage(stage: .awake, duration: 60 * 60, startDate: now, endDate: now.addingTimeInterval(60 * 60)),
        ]
        let output = sut.execute(input: .init(stages: stages))
        #expect(output.efficiency < 100)
        #expect(output.totalMinutes == 360)
    }

    @Test("Score clamped to 0-100")
    func scoreClamped() {
        let now = Date()
        let stages = [
            SleepStage(stage: .deep, duration: 120 * 60, startDate: now, endDate: now.addingTimeInterval(120 * 60)),
            SleepStage(stage: .core, duration: 240 * 60, startDate: now, endDate: now.addingTimeInterval(240 * 60)),
            SleepStage(stage: .rem, duration: 120 * 60, startDate: now, endDate: now.addingTimeInterval(120 * 60)),
        ]
        let output = sut.execute(input: .init(stages: stages))
        #expect(output.score >= 0 && output.score <= 100)
    }

    @Test("Short sleep returns low score")
    func shortSleep() {
        let now = Date()
        let stages = [
            SleepStage(stage: .core, duration: 120 * 60, startDate: now, endDate: now.addingTimeInterval(120 * 60)),
        ]
        let output = sut.execute(input: .init(stages: stages))
        #expect(output.score < 50)
    }

    @Test("Duration score range: 6-10 hours gets 30 points")
    func durationScoreRange() {
        let now = Date()
        // 6 hours exactly
        let stages = [
            SleepStage(stage: .core, duration: 360 * 60, startDate: now, endDate: now.addingTimeInterval(360 * 60)),
        ]
        let output = sut.execute(input: .init(stages: stages))
        // Should get durationScore of 30 (6h is in 6-10 range but not 7-9)
        #expect(output.totalMinutes == 360)
    }

    @Test("Unspecified stage counts toward total sleep time")
    func unspecifiedCountsTowardTotal() {
        let now = Date()
        let stages = [
            SleepStage(stage: .core, duration: 180 * 60, startDate: now, endDate: now.addingTimeInterval(180 * 60)),
            SleepStage(stage: .unspecified, duration: 120 * 60, startDate: now.addingTimeInterval(180 * 60), endDate: now.addingTimeInterval(300 * 60)),
        ]
        let output = sut.execute(input: .init(stages: stages))
        // 3h core + 2h unspecified = 5h total
        #expect(output.totalMinutes == 300)
    }

    @Test("Unspecified stage does not count as deep sleep in ratio")
    func unspecifiedNotDeep() {
        let now = Date()
        // 6h core + 2h unspecified → deep ratio = 0
        let stagesWithUnspecified = [
            SleepStage(stage: .core, duration: 360 * 60, startDate: now, endDate: now.addingTimeInterval(360 * 60)),
            SleepStage(stage: .unspecified, duration: 120 * 60, startDate: now.addingTimeInterval(360 * 60), endDate: now.addingTimeInterval(480 * 60)),
        ]
        // 6h core + 2h deep → deep ratio = 0.25 (ideal range)
        let stagesWithDeep = [
            SleepStage(stage: .core, duration: 360 * 60, startDate: now, endDate: now.addingTimeInterval(360 * 60)),
            SleepStage(stage: .deep, duration: 120 * 60, startDate: now.addingTimeInterval(360 * 60), endDate: now.addingTimeInterval(480 * 60)),
        ]
        let outputUnspecified = sut.execute(input: .init(stages: stagesWithUnspecified))
        let outputDeep = sut.execute(input: .init(stages: stagesWithDeep))
        // Same total minutes
        #expect(outputUnspecified.totalMinutes == outputDeep.totalMinutes)
        // Deep version scores higher because 25% deep is in ideal range
        #expect(outputDeep.score > outputUnspecified.score)
    }

    @Test("Mixed stages with unspecified produces correct efficiency")
    func mixedWithUnspecifiedEfficiency() {
        let now = Date()
        let stages = [
            SleepStage(stage: .deep, duration: 60 * 60, startDate: now, endDate: now.addingTimeInterval(60 * 60)),
            SleepStage(stage: .unspecified, duration: 120 * 60, startDate: now.addingTimeInterval(60 * 60), endDate: now.addingTimeInterval(180 * 60)),
            SleepStage(stage: .awake, duration: 30 * 60, startDate: now.addingTimeInterval(180 * 60), endDate: now.addingTimeInterval(210 * 60)),
        ]
        let output = sut.execute(input: .init(stages: stages))
        // Sleep = deep(60m) + unspecified(120m) = 180m, awake = 30m, total = 210m
        #expect(output.totalMinutes == 180)
        // Efficiency = 180/210 * 100 ≈ 85.7%
        #expect(output.efficiency > 85 && output.efficiency < 86)
    }
}
