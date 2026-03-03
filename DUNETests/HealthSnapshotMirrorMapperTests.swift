import Foundation
import Testing
@testable import DUNE

@Suite("HealthSnapshotMirrorMapper")
struct HealthSnapshotMirrorMapperTests {
    @Test("maps snapshot into payload with sorted time series")
    func mapsSnapshotIntoPayload() {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let twoDaysAgo = Date(timeIntervalSince1970: 1_699_827_200)
        let oneDayAgo = Date(timeIntervalSince1970: 1_699_913_600)
        let todayStart = Date(timeIntervalSince1970: 1_699_999_000)

        let snapshot = SharedHealthSnapshot(
            hrvSamples: [
                HRVSample(value: 58, date: oneDayAgo),
                HRVSample(value: 52, date: twoDaysAgo)
            ],
            todayRHR: 56,
            yesterdayRHR: 59,
            latestRHR: .init(value: 56, date: fetchedAt),
            rhrCollection: [
                (date: oneDayAgo, min: 52, max: 61, average: 56),
                (date: twoDaysAgo, min: 54, max: 63, average: 58)
            ],
            todaySleepStages: [
                SleepStage(stage: .deep, duration: 90 * 60, startDate: todayStart, endDate: todayStart.addingTimeInterval(90 * 60)),
                SleepStage(stage: .core, duration: 180 * 60, startDate: todayStart, endDate: todayStart.addingTimeInterval(270 * 60)),
                SleepStage(stage: .awake, duration: 30 * 60, startDate: todayStart, endDate: todayStart.addingTimeInterval(300 * 60))
            ],
            yesterdaySleepStages: [
                SleepStage(stage: .rem, duration: 80 * 60, startDate: oneDayAgo, endDate: oneDayAgo.addingTimeInterval(80 * 60)),
                SleepStage(stage: .core, duration: 220 * 60, startDate: oneDayAgo, endDate: oneDayAgo.addingTimeInterval(300 * 60))
            ],
            latestSleepStages: .init(stages: [], date: oneDayAgo),
            sleepDailyDurations: [
                .init(
                    date: oneDayAgo,
                    totalMinutes: 380,
                    stageBreakdown: [.deep: 100, .rem: 80, .core: 200]
                ),
                .init(
                    date: twoDaysAgo,
                    totalMinutes: 410,
                    stageBreakdown: [.deep: 110, .rem: 90, .core: 210]
                )
            ],
            conditionScore: ConditionScore(score: 77, date: fetchedAt),
            baselineStatus: BaselineStatus(daysCollected: 5, daysRequired: 7),
            recentConditionScores: [
                ConditionScore(score: 70, date: twoDaysAgo),
                ConditionScore(score: 77, date: oneDayAgo)
            ],
            failedSources: [.todaySleepStages, .todayRHR],
            fetchedAt: fetchedAt
        )

        let payload = HealthSnapshotMirrorMapper.makePayload(from: snapshot)

        #expect(payload.fetchedAt == fetchedAt)
        #expect(payload.failedSources == ["todayRHR", "todaySleepStages"])
        #expect(payload.todayRHR == 56)
        #expect(payload.conditionScore == 77)
        #expect(payload.conditionStatus == ConditionScore(score: 77).status.rawValue)
        #expect(payload.hrv14Day.map(\.value) == [52, 58])
        #expect(payload.rhr14Day.map(\.value) == [58, 56])
        #expect(payload.sleep14Day.map(\.totalMinutes) == [410, 380])
        #expect(payload.todaySleepMinutes == 270)
        #expect(payload.yesterdaySleepMinutes == 300)
        #expect(payload.baselineReady == false)
        #expect(payload.baselineProgress == (5.0 / 7.0))
        #expect(payload.recentScores.map(\.score) == [70, 77])
    }

    @Test("encode/decode roundtrip preserves payload")
    func encodeDecodeRoundtrip() throws {
        let payload = HealthSnapshotMirrorMapper.Payload(
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000.321),
            failedSources: ["hrvSamples"],
            todayRHR: 57,
            yesterdayRHR: 60,
            latestRHR: .init(date: Date(timeIntervalSince1970: 1_700_000_000), value: 57),
            hrv14Day: [.init(date: Date(timeIntervalSince1970: 1_699_000_000), value: 52)],
            rhr14Day: [.init(date: Date(timeIntervalSince1970: 1_699_000_000), value: 58)],
            sleep14Day: [
                .init(
                    date: Date(timeIntervalSince1970: 1_699_000_000),
                    totalMinutes: 420,
                    deepMinutes: 110,
                    remMinutes: 90,
                    coreMinutes: 220,
                    awakeMinutes: 20
                )
            ],
            todaySleepMinutes: 400,
            yesterdaySleepMinutes: 380,
            conditionScore: 74,
            conditionStatus: "good",
            baselineReady: true,
            baselineProgress: 1.0,
            recentScores: [.init(date: Date(timeIntervalSince1970: 1_699_000_000), score: 74)]
        )

        let json = try HealthSnapshotMirrorMapper.encode(payload)
        let decoded = try HealthSnapshotMirrorMapper.decode(json)

        #expect(decoded == payload)
    }
}
