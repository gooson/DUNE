import Foundation

/// Estimates a representative bedtime from recent sleep stage samples.
/// Uses circular-style averaging around midnight by anchoring times before noon to the next day.
struct CalculateAverageBedtimeUseCase: Sendable {

    struct Input: Sendable {
        let sleepStagesByDay: [[SleepStage]]
        let calendar: Calendar

        init(sleepStagesByDay: [[SleepStage]], calendar: Calendar = .current) {
            self.sleepStagesByDay = sleepStagesByDay
            self.calendar = calendar
        }
    }

    /// Returns hour/minute components for the estimated bedtime, or nil when insufficient data.
    func execute(input: Input) -> DateComponents? {
        let bedtimeMinutes = input.sleepStagesByDay.compactMap { dayStages -> Int? in
            guard let bedtime = earliestSleepStart(from: dayStages) else { return nil }
            return minutesFromNoonWrapped(for: bedtime, calendar: input.calendar)
        }

        guard !bedtimeMinutes.isEmpty else { return nil }

        let average = Int((Double(bedtimeMinutes.reduce(0, +)) / Double(bedtimeMinutes.count)).rounded())
        let normalized = ((average % (24 * 60)) + (24 * 60)) % (24 * 60)

        return DateComponents(hour: normalized / 60, minute: normalized % 60)
    }

    private func earliestSleepStart(from stages: [SleepStage]) -> Date? {
        stages
            .filter { $0.stage != .awake }
            .map(\.startDate)
            .min()
    }

    private func minutesFromNoonWrapped(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        var totalMinutes = hour * 60 + minute
        if hour < 12 {
            totalMinutes += 24 * 60
        }
        return totalMinutes
    }
}
