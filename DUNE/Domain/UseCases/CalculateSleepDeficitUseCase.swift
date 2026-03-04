import Foundation

protocol SleepDeficitCalculating: Sendable {
    func execute(input: CalculateSleepDeficitUseCase.Input) -> SleepDeficitAnalysis
}

struct CalculateSleepDeficitUseCase: SleepDeficitCalculating, Sendable {

    // MARK: - Thresholds

    private let minimumShortTermDays = 3
    private let minimumLongTermDays = 7
    private let deficitGood = 120.0        // 2h in minutes
    private let deficitMild = 300.0        // 5h in minutes
    private let deficitModerate = 600.0    // 10h in minutes
    private let recentDaysForDeficit = 7

    // MARK: - Input

    struct Input: Sendable {
        /// Sleep durations for last ~14 days (date + totalMinutes).
        let recentDurations: [DayDuration]

        /// Sleep durations for last ~90 days (date + totalMinutes).
        let longTermDurations: [DayDuration]

        struct DayDuration: Sendable {
            let date: Date
            let totalMinutes: Double
        }
    }

    // MARK: - Execute

    func execute(input: Input) -> SleepDeficitAnalysis {
        // Filter out zero-data days (sensor not worn)
        let validRecent = input.recentDurations.filter { $0.totalMinutes > 0 }
        let validLongTerm = input.longTermDurations.filter { $0.totalMinutes > 0 }

        // Short-term average (14 days)
        guard validRecent.count >= minimumShortTermDays else {
            return SleepDeficitAnalysis(
                shortTermAverage: 0,
                longTermAverage: nil,
                weeklyDeficit: 0,
                dailyDeficits: [],
                level: .insufficient,
                dataPointCount: validRecent.count
            )
        }

        let shortTermAvg = validRecent.map(\.totalMinutes).reduce(0, +) / Double(validRecent.count)

        // Long-term average (90 days) — nil if insufficient
        let longTermAvg: Double?
        if validLongTerm.count >= minimumLongTermDays {
            longTermAvg = validLongTerm.map(\.totalMinutes).reduce(0, +) / Double(validLongTerm.count)
        } else {
            longTermAvg = nil
        }

        // Daily deficits for last 7 days (from recentDurations, sorted oldest-first)
        let sorted = input.recentDurations.sorted { $0.date < $1.date }
        let last7 = sorted.suffix(recentDaysForDeficit)

        var dailyDeficits: [SleepDeficitAnalysis.DailyDeficit] = []
        var weeklyTotal = 0.0

        for day in last7 {
            let deficit: Double
            if day.totalMinutes <= 0 {
                // No data day: skip from deficit calculation (don't penalize)
                deficit = 0
            } else {
                // Deficit = max(0, average - actual). Excess sleep caps at 0 (no carryover).
                deficit = Swift.max(0, shortTermAvg - day.totalMinutes)
            }

            dailyDeficits.append(.init(
                date: day.date,
                actualMinutes: day.totalMinutes,
                deficitMinutes: deficit
            ))
            weeklyTotal += deficit
        }

        let level = classifyLevel(weeklyDeficit: weeklyTotal)

        return SleepDeficitAnalysis(
            shortTermAverage: shortTermAvg,
            longTermAverage: longTermAvg,
            weeklyDeficit: weeklyTotal,
            dailyDeficits: dailyDeficits,
            level: level,
            dataPointCount: validRecent.count
        )
    }

    // MARK: - Private

    private func classifyLevel(weeklyDeficit: Double) -> SleepDeficitAnalysis.DeficitLevel {
        switch weeklyDeficit {
        case ..<deficitGood:
            return .good
        case deficitGood..<deficitMild:
            return .mild
        case deficitMild..<deficitModerate:
            return .moderate
        default:
            return .severe
        }
    }
}
