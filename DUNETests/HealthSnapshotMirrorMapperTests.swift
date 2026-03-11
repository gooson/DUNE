import Foundation
import Testing
@testable import DUNE

@Suite("HealthSnapshotMirrorMapper")
struct HealthSnapshotMirrorMapperTests {
    private let sampleContributions: [ScoreContribution] = [
        ScoreContribution(factor: .hrv, impact: .positive, detail: "58ms — above 52ms avg"),
        ScoreContribution(factor: .rhr, impact: .negative, detail: "59 → 63 bpm (+4)")
    ]

    private func makeConditionDetail(
        todayDate: Date,
        todayRHR: Double? = 63,
        yesterdayRHR: Double? = 59,
        displayRHR: Double? = 63,
        displayRHRDate: Date? = nil
    ) -> ConditionScoreDetail {
        ConditionScoreDetail(
            todayHRV: 58,
            baselineHRV: 52,
            zScore: 0.82,
            stdDev: 0.22,
            effectiveStdDev: 0.25,
            daysInBaseline: 10,
            todayDate: todayDate,
            rawScore: 77.4,
            rhrPenalty: 8,
            todayRHR: todayRHR,
            yesterdayRHR: yesterdayRHR,
            displayRHR: displayRHR,
            displayRHRDate: displayRHRDate ?? todayDate
        )
    }

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
            conditionScore: ConditionScore(
                score: 77,
                date: fetchedAt,
                contributions: sampleContributions,
                detail: makeConditionDetail(todayDate: fetchedAt)
            ),
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
        #expect(payload.conditionContributions == sampleContributions)
        #expect(payload.conditionDetail?.todayRHR == 63)
        #expect(payload.conditionDetail?.yesterdayRHR == 59)
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
            conditionContributions: sampleContributions,
            conditionDetail: makeConditionDetail(
                todayDate: Date(timeIntervalSince1970: 1_700_000_000),
                todayRHR: nil,
                yesterdayRHR: nil,
                displayRHR: 61,
                displayRHRDate: Date(timeIntervalSince1970: 1_699_950_000)
            ),
            baselineReady: true,
            baselineProgress: 1.0,
            recentScores: [.init(date: Date(timeIntervalSince1970: 1_699_000_000), score: 74)]
        )

        let json = try HealthSnapshotMirrorMapper.encode(payload)
        let decoded = try HealthSnapshotMirrorMapper.decode(json)

        #expect(decoded == payload)
    }

    @Test("decode supports legacy payloads without condition detail fields")
    func decodeLegacyPayloadWithoutConditionDetail() throws {
        let legacyJSON = """
        {
          "baselineProgress" : 1,
          "baselineReady" : true,
          "conditionScore" : 74,
          "conditionStatus" : "good",
          "failedSources" : [],
          "fetchedAt" : 1700000000000,
          "hrv14Day" : [],
          "latestRHR" : null,
          "recentScores" : [],
          "rhr14Day" : [],
          "sleep14Day" : [],
          "todayRHR" : 57,
          "todaySleepMinutes" : 400,
          "yesterdayRHR" : 60,
          "yesterdaySleepMinutes" : 380
        }
        """

        let payload = try HealthSnapshotMirrorMapper.decode(legacyJSON)

        #expect(payload.conditionScore == 74)
        #expect(payload.conditionContributions == nil)
        #expect(payload.conditionDetail == nil)
    }

    @Test("makeSnapshot reconstructs shared snapshot from payload")
    func makeSnapshotFromPayload() {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_100_000)
        let payload = HealthSnapshotMirrorMapper.Payload(
            fetchedAt: fetchedAt,
            failedSources: ["todayRHR", "hrvSamples"],
            todayRHR: 58,
            yesterdayRHR: 60,
            latestRHR: .init(date: fetchedAt, value: 58),
            hrv14Day: [.init(date: fetchedAt.addingTimeInterval(-86_400), value: 55)],
            rhr14Day: [.init(date: fetchedAt.addingTimeInterval(-86_400), value: 59)],
            sleep14Day: [
                .init(
                    date: fetchedAt,
                    totalMinutes: 420,
                    deepMinutes: 90,
                    remMinutes: 80,
                    coreMinutes: 230,
                    awakeMinutes: 20
                )
            ],
            todaySleepMinutes: 400,
            yesterdaySleepMinutes: 380,
            conditionScore: 75,
            conditionStatus: "good",
            conditionContributions: sampleContributions,
            conditionDetail: makeConditionDetail(
                todayDate: fetchedAt,
                todayRHR: nil,
                yesterdayRHR: 60,
                displayRHR: 58,
                displayRHRDate: fetchedAt.addingTimeInterval(-86_400)
            ),
            baselineReady: nil,
            baselineProgress: nil,
            recentScores: [.init(date: fetchedAt.addingTimeInterval(-86_400), score: 72)]
        )

        let snapshot = HealthSnapshotMirrorMapper.makeSnapshot(from: payload)

        #expect(snapshot.fetchedAt == fetchedAt)
        #expect(snapshot.todayRHR == 58)
        #expect(snapshot.latestRHR?.value == 58)
        #expect(snapshot.hrvSamples.count == 1)
        #expect(snapshot.rhrCollection.count == 1)
        #expect(snapshot.sleepDailyDurations.first?.totalMinutes == 420)
        #expect(snapshot.todaySleepStages.isEmpty == false)
        #expect(snapshot.conditionScore?.score == 75)
        #expect(snapshot.conditionScore?.contributions == sampleContributions)
        #expect(snapshot.conditionScore?.detail?.displayRHR == 58)
        #expect(snapshot.conditionScore?.detail?.displayRHRDate == fetchedAt.addingTimeInterval(-86_400))
        #expect(snapshot.recentConditionScores.map(\.score) == [72])
        #expect(snapshot.failedSources.contains(.todayRHR))
        #expect(snapshot.failedSources.contains(.hrvSamples))
    }
}
