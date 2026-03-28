import Testing
@testable import DUNE

@Suite("DetectNapsUseCase Tests")
struct DetectNapsUseCaseTests {
    let sut = DetectNapsUseCase()
    let calendar = Calendar.current

    private func makeStage(_ stage: SleepStage.Stage, start: Date, durationMinutes: Double) -> SleepStage {
        SleepStage(stage: stage, startDate: start, endDate: start.addingTimeInterval(durationMinutes * 60))
    }

    private func dateAt(hour: Int, minute: Int = 0, daysAgo: Int = 0) -> Date {
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    @Test("Detects 30+ minute daytime nap")
    func detectsDaytimeNap() {
        let stages = [
            makeStage(.light, start: dateAt(hour: 14), durationMinutes: 45),
        ]
        let result = sut.execute(input: .init(sleepStagesByDay: [stages], calendar: calendar, analysisDays: 7))
        #expect(result.naps.count == 1)
        #expect(result.naps[0].durationMinutes == 45)
    }

    @Test("Ignores naps shorter than 30 minutes")
    func ignoresShortNaps() {
        let stages = [
            makeStage(.light, start: dateAt(hour: 14), durationMinutes: 20),
        ]
        let result = sut.execute(input: .init(sleepStagesByDay: [stages], calendar: calendar, analysisDays: 7))
        #expect(result.naps.isEmpty)
    }

    @Test("Ignores nighttime sleep sessions")
    func ignoresNighttimeSleep() {
        let stages = [
            makeStage(.deep, start: dateAt(hour: 23), durationMinutes: 60),
        ]
        let result = sut.execute(input: .init(sleepStagesByDay: [stages], calendar: calendar, analysisDays: 7))
        #expect(result.naps.isEmpty)
    }

    @Test("Ignores early morning sessions before 06:00")
    func ignoresEarlyMorningSleep() {
        let stages = [
            makeStage(.light, start: dateAt(hour: 4), durationMinutes: 45),
        ]
        let result = sut.execute(input: .init(sleepStagesByDay: [stages], calendar: calendar, analysisDays: 7))
        #expect(result.naps.isEmpty)
    }

    @Test("Computes average duration correctly")
    func computesAverageDuration() {
        let stages = [
            [makeStage(.light, start: dateAt(hour: 13, daysAgo: 1), durationMinutes: 30)],
            [makeStage(.light, start: dateAt(hour: 15, daysAgo: 2), durationMinutes: 60)],
        ]
        let result = sut.execute(input: .init(sleepStagesByDay: stages, calendar: calendar, analysisDays: 14))
        #expect(result.naps.count == 2)
        #expect(result.averageDurationMinutes == 45.0)
    }

    @Test("Computes frequency per week")
    func computesFrequency() {
        let stages = [
            [makeStage(.light, start: dateAt(hour: 14, daysAgo: 1), durationMinutes: 35)],
            [makeStage(.light, start: dateAt(hour: 14, daysAgo: 3), durationMinutes: 40)],
        ]
        let result = sut.execute(input: .init(sleepStagesByDay: stages, calendar: calendar, analysisDays: 7))
        #expect(result.frequencyPerWeek == 2.0)
    }

    @Test("Returns nil frequency for less than 7 analysis days")
    func nilFrequencyForShortPeriod() {
        let stages = [
            [makeStage(.light, start: dateAt(hour: 14), durationMinutes: 35)],
        ]
        let result = sut.execute(input: .init(sleepStagesByDay: stages, calendar: calendar, analysisDays: 5))
        #expect(result.frequencyPerWeek == nil)
    }
}
