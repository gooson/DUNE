import Foundation
import Testing
@testable import Dailve

@Suite("SharedHealthSnapshot")
struct SharedHealthSnapshotTests {

    @Test("hrvSamples14Day filters to recent samples")
    func hrvSamples14DayFiltering() {
        let now = Date()
        let recent = HRVSample(value: 52, date: now)
        let old = HRVSample(value: 43, date: Calendar.current.date(byAdding: .day, value: -20, to: now) ?? now)

        let snapshot = makeSnapshot(
            fetchedAt: now,
            hrvSamples: [recent, old]
        )

        #expect(snapshot.hrvSamples14Day.count == 1)
        #expect(snapshot.hrvSamples14Day.first?.value == 52)
    }

    @Test("effectiveRHR prefers today value")
    func effectiveRHRPrefersToday() {
        let now = Date()
        let snapshot = makeSnapshot(
            fetchedAt: now,
            todayRHR: 57,
            latestRHR: .init(value: 62, date: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now)
        )

        #expect(snapshot.effectiveRHR?.value == 57)
        #expect(snapshot.effectiveRHR?.isHistorical == false)
    }

    @Test("sleepScoreInput falls back to latest stages")
    func sleepScoreInputFallbackToLatest() {
        let now = Date()
        let latestDate = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let latestStages = [
            SleepStage(stage: .deep, duration: 60 * 60, startDate: latestDate, endDate: latestDate.addingTimeInterval(60 * 60))
        ]

        let snapshot = makeSnapshot(
            fetchedAt: now,
            todaySleepStages: [],
            latestSleepStages: .init(stages: latestStages, date: latestDate)
        )

        #expect(snapshot.sleepScoreInput != nil)
        #expect(snapshot.sleepScoreInput?.isHistorical == true)
        #expect(snapshot.sleepScoreInput?.stages.count == 1)
    }

    @Test("sleepSummaryForRecovery is computed from today's stages")
    func sleepSummaryForRecoveryFromTodayStages() {
        let now = Date()
        let stages = [
            SleepStage(stage: .deep, duration: 90 * 60, startDate: now, endDate: now.addingTimeInterval(90 * 60)),
            SleepStage(stage: .rem, duration: 60 * 60, startDate: now, endDate: now.addingTimeInterval(150 * 60)),
            SleepStage(stage: .core, duration: 210 * 60, startDate: now, endDate: now.addingTimeInterval(360 * 60)),
            SleepStage(stage: .awake, duration: 30 * 60, startDate: now, endDate: now.addingTimeInterval(390 * 60))
        ]

        let snapshot = makeSnapshot(
            fetchedAt: now,
            todaySleepStages: stages
        )

        let summary = snapshot.sleepSummaryForRecovery
        #expect(summary != nil)
        #expect(summary?.totalSleepMinutes == 360)
        #expect(summary?.deepSleepRatio == 0.25)
        #expect(summary?.remSleepRatio == (60.0 / 360.0))
    }

    private func makeSnapshot(
        fetchedAt: Date,
        hrvSamples: [HRVSample] = [],
        todayRHR: Double? = nil,
        latestRHR: SharedHealthSnapshot.RHRSample? = nil,
        todaySleepStages: [SleepStage] = [],
        latestSleepStages: SharedHealthSnapshot.SleepStagesSample? = nil
    ) -> SharedHealthSnapshot {
        SharedHealthSnapshot(
            hrvSamples: hrvSamples,
            todayRHR: todayRHR,
            yesterdayRHR: nil,
            latestRHR: latestRHR,
            rhrCollection: [],
            todaySleepStages: todaySleepStages,
            yesterdaySleepStages: [],
            latestSleepStages: latestSleepStages,
            sleepDailyDurations: [],
            conditionScore: nil,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: fetchedAt
        )
    }
}
