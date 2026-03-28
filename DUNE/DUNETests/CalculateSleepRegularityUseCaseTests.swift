import Testing
@testable import DUNE

@Suite("CalculateSleepRegularityUseCase Tests")
struct CalculateSleepRegularityUseCaseTests {
    let sut = CalculateSleepRegularityUseCase()
    let calendar = Calendar.current

    private func makeStages(bedtimeHour: Int, bedtimeMinute: Int = 0, durationHours: Double = 8, daysAgo: Int = 0) -> [SleepStage] {
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        let bedtime = calendar.date(bySettingHour: bedtimeHour, minute: bedtimeMinute, second: 0, of: day)!
        let wakeTime = bedtime.addingTimeInterval(durationHours * 3600)

        return [
            SleepStage(stage: .light, startDate: bedtime, endDate: bedtime.addingTimeInterval(2 * 3600)),
            SleepStage(stage: .deep, startDate: bedtime.addingTimeInterval(2 * 3600), endDate: bedtime.addingTimeInterval(4 * 3600)),
            SleepStage(stage: .rem, startDate: bedtime.addingTimeInterval(4 * 3600), endDate: wakeTime),
        ]
    }

    @Test("Returns nil for fewer than 3 nights")
    func nilForInsufficientData() {
        let stages = [
            makeStages(bedtimeHour: 23, daysAgo: 1),
            makeStages(bedtimeHour: 23, daysAgo: 2),
        ]
        let result = sut.execute(input: .init(sleepStagesByDay: stages, calendar: calendar))
        #expect(result == nil)
    }

    @Test("Perfect regularity scores near 100")
    func perfectRegularity() {
        let stages = (1...7).map { makeStages(bedtimeHour: 23, daysAgo: $0) }
        let result = sut.execute(input: .init(sleepStagesByDay: stages, calendar: calendar))
        #expect(result != nil)
        #expect(result!.score >= 95)
    }

    @Test("High variation scores low")
    func highVariation() {
        let stages = [
            makeStages(bedtimeHour: 21, daysAgo: 1),
            makeStages(bedtimeHour: 1, daysAgo: 2),
            makeStages(bedtimeHour: 23, daysAgo: 3),
            makeStages(bedtimeHour: 3, daysAgo: 4),
        ]
        let result = sut.execute(input: .init(sleepStagesByDay: stages, calendar: calendar))
        #expect(result != nil)
        #expect(result!.score < 60)
    }

    @Test("Confidence low for under 7 nights")
    func confidenceLowForFewNights() {
        let stages = (1...5).map { makeStages(bedtimeHour: 23, daysAgo: $0) }
        let result = sut.execute(input: .init(sleepStagesByDay: stages, calendar: calendar))
        #expect(result?.confidence == .low)
    }

    @Test("Confidence high for 14+ nights")
    func confidenceHighForManyNights() {
        let stages = (1...15).map { makeStages(bedtimeHour: 23, daysAgo: $0) }
        let result = sut.execute(input: .init(sleepStagesByDay: stages, calendar: calendar))
        #expect(result?.confidence == .high)
    }
}
