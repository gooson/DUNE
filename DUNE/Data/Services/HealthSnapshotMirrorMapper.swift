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
        let conditionContributions: [ScoreContribution]?
        let conditionDetail: ConditionScoreDetail?
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
            conditionContributions: snapshot.conditionScore?.contributions,
            conditionDetail: snapshot.conditionScore?.detail,
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

    static func makeSnapshot(from payload: Payload) -> SharedHealthSnapshot {
        let hrvSamples = payload.hrv14Day.map { HRVSample(value: $0.value, date: $0.date) }
        let rhrCollection = payload.rhr14Day.map { point in
            (date: point.date, min: point.value, max: point.value, average: point.value)
        }

        let sleepDailyDurations = payload.sleep14Day.map { point in
            SharedHealthSnapshot.SleepDailyDuration(
                date: point.date,
                totalMinutes: point.totalMinutes,
                stageBreakdown: [
                    .deep: point.deepMinutes,
                    .rem: point.remMinutes,
                    .core: point.coreMinutes,
                    .awake: point.awakeMinutes
                ]
            )
        }

        let latestSleepPoint = payload.sleep14Day.max(by: { $0.date < $1.date })
        let latestSleepStages: SharedHealthSnapshot.SleepStagesSample? = latestSleepPoint.map { point in
            SharedHealthSnapshot.SleepStagesSample(
                stages: synthesizeSleepStages(from: point),
                date: point.date
            )
        }

        let todayStages = payload.sleep14Day
            .first(where: { Calendar.current.isDate($0.date, inSameDayAs: payload.fetchedAt) })
            .map(synthesizeSleepStages(from:))
            ?? []

        let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: payload.fetchedAt) ?? payload.fetchedAt
        let yesterdayStages = payload.sleep14Day
            .first(where: { Calendar.current.isDate($0.date, inSameDayAs: yesterdayDate) })
            .map(synthesizeSleepStages(from:))
            ?? []

        let recentScores = payload.recentScores.map { point in
            ConditionScore(score: point.score, date: point.date)
        }

        let failedSources: Set<SharedHealthSnapshot.Source> = Set(
            payload.failedSources.compactMap(SharedHealthSnapshot.Source.init(rawValue:))
        )
        let conditionScore = restoredConditionScore(from: payload, hrvSamples: hrvSamples)

        return SharedHealthSnapshot(
            hrvSamples: hrvSamples,
            todayRHR: payload.todayRHR,
            yesterdayRHR: payload.yesterdayRHR,
            latestRHR: payload.latestRHR.map {
                SharedHealthSnapshot.RHRSample(value: $0.value, date: $0.date)
            },
            rhrCollection: rhrCollection,
            todaySleepStages: todayStages,
            yesterdaySleepStages: yesterdayStages,
            latestSleepStages: latestSleepStages,
            sleepDailyDurations: sleepDailyDurations,
            conditionScore: conditionScore,
            baselineStatus: nil,
            recentConditionScores: recentScores,
            failedSources: failedSources,
            fetchedAt: payload.fetchedAt
        )
    }

    private static func sleepTotalMinutes(from stages: [SleepStage]) -> Double {
        stages
            .filter { $0.stage != .awake }
            .reduce(0.0) { $0 + $1.duration / 60.0 }
    }

    private static func synthesizeSleepStages(from point: Payload.SleepDailyPoint) -> [SleepStage] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: point.date)
        var cursor = dayStart
        var stages: [SleepStage] = []

        func appendStage(_ stage: SleepStage.Stage, minutes: Double) {
            guard minutes > 0, minutes.isFinite else { return }
            let duration = minutes * 60.0
            let startDate = cursor
            let endDate = startDate.addingTimeInterval(duration)
            stages.append(
                SleepStage(
                    stage: stage,
                    duration: duration,
                    startDate: startDate,
                    endDate: endDate
                )
            )
            cursor = endDate
        }

        appendStage(.deep, minutes: point.deepMinutes)
        appendStage(.rem, minutes: point.remMinutes)
        appendStage(.core, minutes: point.coreMinutes)
        appendStage(.awake, minutes: point.awakeMinutes)

        return stages
    }

    private static func restoredConditionScore(
        from payload: Payload,
        hrvSamples: [HRVSample]
    ) -> ConditionScore? {
        guard let storedScore = payload.conditionScore else { return nil }

        if payload.conditionDetail != nil || payload.conditionContributions != nil {
            return ConditionScore(
                score: storedScore,
                date: payload.fetchedAt,
                contributions: payload.conditionContributions ?? [],
                detail: payload.conditionDetail
            )
        }

        let displayRHR = payload.todayRHR ?? payload.latestRHR?.value
        let displayRHRDate = payload.todayRHR != nil ? payload.fetchedAt : payload.latestRHR?.date
        let recovered = CalculateConditionScoreUseCase().execute(
            input: .init(
                hrvSamples: hrvSamples,
                todayRHR: payload.todayRHR,
                yesterdayRHR: payload.yesterdayRHR,
                displayRHR: displayRHR,
                displayRHRDate: displayRHRDate
            )
        )

        guard let recoveredScore = recovered.score else {
            return ConditionScore(score: storedScore, date: payload.fetchedAt)
        }

        return ConditionScore(
            score: recoveredScore.score,
            date: payload.fetchedAt,
            contributions: recoveredScore.contributions,
            detail: recoveredScore.detail
        )
    }
}
