import Foundation
import Testing
@testable import DUNE

@Suite("ImmersiveRecoveryAnalyzer")
struct ImmersiveRecoveryAnalyzerTests {
    private let sut = ImmersiveRecoveryAnalyzer()
    private let calendar = Calendar.current

    @Test("high condition score creates sunrise atmosphere and sustain cadence")
    func sunriseAtmosphereForHighCondition() {
        let now = Date()
        let snapshot = makeSnapshot(
            fetchedAt: now,
            conditionScore: ConditionScore(score: 95, date: now)
        )

        let summary = sut.buildSummary(from: snapshot, generatedAt: now)

        #expect(summary.atmosphere.preset == .sunrise)
        #expect(summary.atmosphere.score == 95)
        #expect(summary.recoverySession.recommendation == .sustain)
        #expect(summary.recoverySession.cadence.totalCycleSeconds == 9)
    }

    @Test("low condition and short deep sleep recommend restore mode")
    func restoreRecommendationForLowRecovery() {
        let now = Date()
        let stages = [
            sleepStage(.core, minutes: 140, startOffsetMinutes: -280, from: now),
            sleepStage(.deep, minutes: 24, startOffsetMinutes: -140, from: now),
            sleepStage(.rem, minutes: 36, startOffsetMinutes: -116, from: now),
        ]
        let snapshot = makeSnapshot(
            fetchedAt: now,
            todaySleepStages: stages,
            conditionScore: ConditionScore(score: 42, date: now)
        )

        let summary = sut.buildSummary(from: snapshot, generatedAt: now)

        #expect(summary.atmosphere.preset == .storm)
        #expect(summary.recoverySession.recommendation == .restore)
        #expect(summary.recoverySession.suggestedDurationMinutes == 6)
    }

    @Test("sleep journey falls back to latest stages and compresses contiguous segments")
    func latestSleepFallbackCompression() {
        let now = Date()
        let latestDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let stages = [
            sleepStage(.awake, minutes: 12, startOffsetMinutes: 0, from: latestDate),
            sleepStage(.core, minutes: 40, startOffsetMinutes: 12, from: latestDate),
            sleepStage(.core, minutes: 20, startOffsetMinutes: 52, from: latestDate),
            sleepStage(.deep, minutes: 70, startOffsetMinutes: 72, from: latestDate),
            sleepStage(.rem, minutes: 30, startOffsetMinutes: 142, from: latestDate),
        ]
        let snapshot = makeSnapshot(
            fetchedAt: now,
            latestSleepStages: .init(stages: stages, date: latestDate)
        )

        let summary = sut.buildSummary(from: snapshot, generatedAt: now)

        #expect(summary.sleepJourney.isHistorical == true)
        #expect(summary.sleepJourney.hasData == true)
        #expect(summary.sleepJourney.segments.count == 4)
        #expect(summary.sleepJourney.segments[1].durationMinutes == 60)
        #expect(summary.sleepJourney.segments.last?.endProgress == 1)
    }

    @Test("nil snapshot returns fallback guidance without sleep journey data")
    func fallbackWithoutSnapshot() {
        let summary = sut.buildSummary(from: nil, generatedAt: Date())

        #expect(summary.atmosphere.preset == .mist)
        #expect(summary.sleepJourney.hasData == false)
        #expect(summary.message == String(localized: "Shared snapshot service isn't connected."))
    }

    private func sleepStage(
        _ stage: SleepStage.Stage,
        minutes: Double,
        startOffsetMinutes: Double,
        from anchor: Date
    ) -> SleepStage {
        let startDate = anchor.addingTimeInterval(startOffsetMinutes * 60)
        let endDate = startDate.addingTimeInterval(minutes * 60)
        return SleepStage(
            stage: stage,
            duration: minutes * 60,
            startDate: startDate,
            endDate: endDate
        )
    }

    private func makeSnapshot(
        fetchedAt: Date,
        todaySleepStages: [SleepStage] = [],
        latestSleepStages: SharedHealthSnapshot.SleepStagesSample? = nil,
        conditionScore: ConditionScore? = nil
    ) -> SharedHealthSnapshot {
        SharedHealthSnapshot(
            hrvSamples: [],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil,
            rhrCollection: [],
            todaySleepStages: todaySleepStages,
            yesterdaySleepStages: [],
            latestSleepStages: latestSleepStages,
            sleepDailyDurations: [],
            conditionScore: conditionScore,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: fetchedAt
        )
    }
}
