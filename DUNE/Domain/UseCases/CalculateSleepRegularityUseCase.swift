import Foundation

protocol SleepRegularityCalculating: Sendable {
    func execute(input: CalculateSleepRegularityUseCase.Input) -> SleepRegularityIndex?
}

/// Computes Sleep Regularity Index from bedtime/wake time consistency.
///
/// Uses circular averaging around midnight (same technique as CalculateAverageBedtimeUseCase)
/// then computes standard deviation. Score = max(0, 100 - avgStdDev) where avgStdDev is
/// the mean of bedtime and wake time standard deviations in minutes.
struct CalculateSleepRegularityUseCase: SleepRegularityCalculating, Sendable {

    struct Input: Sendable {
        let sleepStagesByDay: [[SleepStage]]
        let calendar: Calendar

        init(sleepStagesByDay: [[SleepStage]], calendar: Calendar = .current) {
            self.sleepStagesByDay = sleepStagesByDay
            self.calendar = calendar
        }
    }

    func execute(input: Input) -> SleepRegularityIndex? {
        let timePairs = input.sleepStagesByDay.compactMap { dayStages -> (bedtime: Int, wakeTime: Int)? in
            let sleepStages = dayStages.filter { $0.stage != .awake }
            guard !sleepStages.isEmpty else { return nil }

            let bedtime = sleepStages.map(\.startDate).min()!
            let wakeTime = sleepStages.map(\.endDate).max()!

            return (
                bedtime: minutesFromNoonWrapped(for: bedtime, calendar: input.calendar),
                wakeTime: minutesFromMidnightWrapped(for: wakeTime, calendar: input.calendar)
            )
        }

        guard timePairs.count >= 3 else { return nil }

        let bedtimeMinutes = timePairs.map(\.bedtime)
        let wakeMinutes = timePairs.map(\.wakeTime)

        let bedtimeAvg = Double(bedtimeMinutes.reduce(0, +)) / Double(bedtimeMinutes.count)
        let wakeAvg = Double(wakeMinutes.reduce(0, +)) / Double(wakeMinutes.count)

        let bedtimeStdDev = standardDeviation(bedtimeMinutes.map(Double.init), mean: bedtimeAvg)
        let wakeStdDev = standardDeviation(wakeMinutes.map(Double.init), mean: wakeAvg)

        let avgStdDev = (bedtimeStdDev + wakeStdDev) / 2.0
        let score = max(0, min(100, Int((100.0 - avgStdDev).rounded())))

        let normalizedBedtime = ((Int(bedtimeAvg.rounded()) % (24 * 60)) + (24 * 60)) % (24 * 60)
        let normalizedWake = ((Int(wakeAvg.rounded()) % (24 * 60)) + (24 * 60)) % (24 * 60)

        let confidence: SleepRegularityIndex.Confidence = switch timePairs.count {
        case ..<7: .low
        case 7..<14: .medium
        default: .high
        }

        return SleepRegularityIndex(
            score: score,
            bedtimeStdDevMinutes: bedtimeStdDev,
            wakeTimeStdDevMinutes: wakeStdDev,
            averageBedtime: DateComponents(hour: normalizedBedtime / 60, minute: normalizedBedtime % 60),
            averageWakeTime: DateComponents(hour: normalizedWake / 60, minute: normalizedWake % 60),
            dataPointCount: timePairs.count,
            confidence: confidence
        )
    }

    /// Circular wrapping around noon for bedtime (same as CalculateAverageBedtimeUseCase).
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

    /// Simple minutes-from-midnight for wake time (typically morning hours).
    private func minutesFromMidnightWrapped(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func standardDeviation(_ values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        let sumOfSquares = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
        return (sumOfSquares / Double(values.count)).squareRoot()
    }
}
