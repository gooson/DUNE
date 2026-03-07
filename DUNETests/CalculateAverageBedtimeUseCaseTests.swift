import Foundation
import Testing
@testable import DUNE

@Suite("CalculateAverageBedtimeUseCase")
struct CalculateAverageBedtimeUseCaseTests {

    private let useCase = CalculateAverageBedtimeUseCase()

    @Test("returns nil when no sleep stages are available")
    func returnsNilWithoutData() {
        let result = useCase.execute(input: .init(sleepStagesByDay: []))
        #expect(result == nil)
    }

    @Test("calculates average bedtime around midnight without drifting to noon")
    func averagesAroundMidnight() {
        let calendar = Calendar(identifier: .gregorian)

        let day1 = makeStages(startHour: 23, startMinute: 40, durationMinutes: 420)
        let day2 = makeStages(startHour: 0, startMinute: 10, durationMinutes: 390)
        let day3 = makeStages(startHour: 23, startMinute: 55, durationMinutes: 405)

        let result = useCase.execute(input: .init(
            sleepStagesByDay: [day1, day2, day3],
            calendar: calendar
        ))

        #expect(result?.hour == 23)
        #expect(result?.minute == 55)
    }

    @Test("ignores awake-only days")
    func ignoresAwakeOnlyDays() {
        let asleep = makeStages(startHour: 22, startMinute: 30, durationMinutes: 420)
        let awakeOnly = [
            SleepStage(
                stage: .awake,
                duration: 120,
                startDate: Date(timeIntervalSince1970: 1_700_100_000),
                endDate: Date(timeIntervalSince1970: 1_700_100_120)
            )
        ]

        let result = useCase.execute(input: .init(
            sleepStagesByDay: [awakeOnly, asleep]
        ))

        #expect(result?.hour == 22)
        #expect(result?.minute == 30)
    }

    private func makeStages(startHour: Int, startMinute: Int, durationMinutes: Int) -> [SleepStage] {
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: base) ?? base
        let end = start.addingTimeInterval(Double(durationMinutes * 60))

        return [
            SleepStage(stage: .core, duration: end.timeIntervalSince(start), startDate: start, endDate: end)
        ]
    }
}
