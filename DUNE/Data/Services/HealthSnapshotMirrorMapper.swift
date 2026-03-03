import Foundation

enum HealthSnapshotMirrorMapper {
    struct Payload: Codable, Sendable, Equatable {
        struct HRVPoint: Codable, Sendable, Equatable {
            let date: Date
            let value: Double
        }

        struct RHRPoint: Codable, Sendable, Equatable {
            let date: Date
            let value: Double
        }

        struct SleepDailyPoint: Codable, Sendable, Equatable {
            let date: Date
            let totalMinutes: Double
            let deepMinutes: Double
            let remMinutes: Double
            let coreMinutes: Double
            let awakeMinutes: Double
        }

        struct ScorePoint: Codable, Sendable, Equatable {
            let date: Date
            let score: Int
        }

        let fetchedAt: Date
        let failedSources: [String]

        let todayRHR: Double?
        let yesterdayRHR: Double?
        let latestRHR: RHRPoint?

        let hrv14Day: [HRVPoint]
        let rhr14Day: [RHRPoint]
        let sleep14Day: [SleepDailyPoint]

        let todaySleepMinutes: Double
        let yesterdaySleepMinutes: Double

        let conditionScore: Int?
        let conditionStatus: String?
        let baselineReady: Bool?
        let baselineProgress: Double?
        let recentScores: [ScorePoint]
    }

    static func makePayload(from snapshot: SharedHealthSnapshot) -> Payload {
        let hrv14Day = snapshot.hrvSamples14Day
            .map { Payload.HRVPoint(date: $0.date, value: $0.value) }
            .sorted { $0.date < $1.date }

        let rhr14Day = snapshot.rhrCollection14Day
            .map { Payload.RHRPoint(date: $0.date, value: $0.average) }
            .sorted { $0.date < $1.date }

        let sleep14Day = snapshot.sleepDailyDurations
            .map {
                Payload.SleepDailyPoint(
                    date: $0.date,
                    totalMinutes: $0.totalMinutes,
                    deepMinutes: $0.stageBreakdown[.deep] ?? 0,
                    remMinutes: $0.stageBreakdown[.rem] ?? 0,
                    coreMinutes: $0.stageBreakdown[.core] ?? 0,
                    awakeMinutes: $0.stageBreakdown[.awake] ?? 0
                )
            }
            .sorted { $0.date < $1.date }

        let recentScores = snapshot.recentConditionScores
            .map { Payload.ScorePoint(date: $0.date, score: $0.score) }
            .sorted { $0.date < $1.date }

        return Payload(
            fetchedAt: snapshot.fetchedAt,
            failedSources: snapshot.failedSources.map(\.rawValue).sorted(),
            todayRHR: snapshot.todayRHR,
            yesterdayRHR: snapshot.yesterdayRHR,
            latestRHR: snapshot.latestRHR.map { Payload.RHRPoint(date: $0.date, value: $0.value) },
            hrv14Day: hrv14Day,
            rhr14Day: rhr14Day,
            sleep14Day: sleep14Day,
            todaySleepMinutes: sleepTotalMinutes(from: snapshot.todaySleepStages),
            yesterdaySleepMinutes: sleepTotalMinutes(from: snapshot.yesterdaySleepStages),
            conditionScore: snapshot.conditionScore?.score,
            conditionStatus: snapshot.conditionScore?.status.rawValue,
            baselineReady: snapshot.baselineStatus?.isReady,
            baselineProgress: snapshot.baselineStatus?.progress,
            recentScores: recentScores
        )
    }

    static func encode(_ payload: Payload) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                payload,
                .init(codingPath: [], debugDescription: "Failed to encode payload as UTF-8 string")
            )
        }
        return json
    }

    static func decode(_ json: String) throws -> Payload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let data = Data(json.utf8)
        return try decoder.decode(Payload.self, from: data)
    }

    private static func sleepTotalMinutes(from stages: [SleepStage]) -> Double {
        stages
            .filter { $0.stage != .awake }
            .reduce(0.0) { $0 + $1.duration / 60.0 }
    }
}
