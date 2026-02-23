import Foundation

struct SharedHealthSnapshot: Sendable {
    enum Source: String, Sendable, Hashable, CaseIterable {
        case hrvSamples
        case todayRHR
        case yesterdayRHR
        case latestRHR
        case rhrCollection
        case todaySleepStages
        case yesterdaySleepStages
        case latestSleepStages
        case sleepDailyDurations
    }

    struct RHRSample: Sendable {
        let value: Double
        let date: Date
    }

    struct SleepStagesSample: Sendable {
        let stages: [SleepStage]
        let date: Date
    }

    struct SleepDailyDuration: Sendable {
        let date: Date
        let totalMinutes: Double
        let stageBreakdown: [SleepStage.Stage: Double]
    }

    struct EffectiveRHR: Sendable {
        let value: Double
        let date: Date
        let isHistorical: Bool
    }

    struct SleepScoreInput: Sendable {
        let stages: [SleepStage]
        let date: Date
        let isHistorical: Bool
    }

    let hrvSamples: [HRVSample]
    let todayRHR: Double?
    let yesterdayRHR: Double?
    let latestRHR: RHRSample?
    let rhrCollection: [(date: Date, min: Double, max: Double, average: Double)]

    let todaySleepStages: [SleepStage]
    let yesterdaySleepStages: [SleepStage]
    let latestSleepStages: SleepStagesSample?
    let sleepDailyDurations: [SleepDailyDuration]

    let conditionScore: ConditionScore?
    let baselineStatus: BaselineStatus?
    let recentConditionScores: [ConditionScore]

    let failedSources: Set<Source>
    let fetchedAt: Date

    var hrvSamples14Day: [HRVSample] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -14, to: fetchedAt) ?? fetchedAt
        return hrvSamples
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
    }

    var rhrCollection14Day: [(date: Date, average: Double)] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -14, to: fetchedAt) ?? fetchedAt
        return rhrCollection
            .filter { $0.date >= cutoff }
            .map { (date: $0.date, average: $0.average) }
            .sorted { $0.date < $1.date }
    }

    var effectiveRHR: EffectiveRHR? {
        let calendar = Calendar.current
        if let todayRHR {
            return EffectiveRHR(
                value: todayRHR,
                date: calendar.startOfDay(for: fetchedAt),
                isHistorical: false
            )
        }
        if let latestRHR {
            return EffectiveRHR(value: latestRHR.value, date: latestRHR.date, isHistorical: true)
        }
        return nil
    }

    var sleepScoreInput: SleepScoreInput? {
        let calendar = Calendar.current
        if !todaySleepStages.isEmpty {
            return SleepScoreInput(
                stages: todaySleepStages,
                date: calendar.startOfDay(for: fetchedAt),
                isHistorical: false
            )
        }
        if let latestSleepStages {
            return SleepScoreInput(
                stages: latestSleepStages.stages,
                date: latestSleepStages.date,
                isHistorical: true
            )
        }
        return nil
    }

    var sleepSummaryForRecovery: SleepSummary? {
        let sleepStages = todaySleepStages.filter { $0.stage != .awake }
        guard !sleepStages.isEmpty else { return nil }

        let totalSeconds = sleepStages.reduce(0.0) { $0 + $1.duration }
        guard totalSeconds > 0 else { return nil }

        let deepSeconds = sleepStages
            .filter { $0.stage == .deep }
            .reduce(0.0) { $0 + $1.duration }
        let remSeconds = sleepStages
            .filter { $0.stage == .rem }
            .reduce(0.0) { $0 + $1.duration }

        return SleepSummary(
            totalSleepMinutes: totalSeconds / 60.0,
            deepSleepRatio: min(1.0, deepSeconds / totalSeconds),
            remSleepRatio: min(1.0, remSeconds / totalSeconds),
            date: Calendar.current.startOfDay(for: fetchedAt)
        )
    }
}
