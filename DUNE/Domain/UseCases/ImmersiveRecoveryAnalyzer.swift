import Foundation

protocol ImmersiveRecoveryAnalyzing: Sendable {
    func buildSummary(
        from snapshot: SharedHealthSnapshot?,
        generatedAt: Date
    ) -> ImmersiveRecoverySummary
}

struct ImmersiveRecoveryAnalyzer: ImmersiveRecoveryAnalyzing, Sendable {
    func buildSummary(
        from snapshot: SharedHealthSnapshot?,
        generatedAt: Date = Date()
    ) -> ImmersiveRecoverySummary {
        guard let snapshot else {
            return ImmersiveRecoverySummary(
                atmosphere: .init(
                    preset: .mist,
                    score: nil,
                    title: String(localized: "Recovery Atmosphere"),
                    subtitle: String(localized: "Health data is unavailable, so DUNE is showing a guided fallback scene.")
                ),
                recoverySession: .init(
                    recommendation: .rebalance,
                    title: String(localized: "Reset your rhythm"),
                    subtitle: String(localized: "Use a short guided breathing cycle while your health data reconnects."),
                    cadence: .init(inhaleSeconds: 4, inhaleHoldSeconds: 1, exhaleSeconds: 6, exhaleHoldSeconds: 1, cycles: 6),
                    suggestedDurationMinutes: 4,
                    shouldPersistMindfulSession: false
                ),
                sleepJourney: .init(
                    title: String(localized: "Sleep Journey"),
                    subtitle: String(localized: "Sleep stages will appear after your next synced night."),
                    date: nil,
                    isHistorical: false,
                    totalMinutes: 0,
                    segments: []
                ),
                generatedAt: generatedAt,
                message: String(localized: "Shared snapshot service isn't connected.")
            )
        }

        let sleepSource = resolvedSleepSource(from: snapshot)
        let sleepJourney = buildSleepJourney(from: sleepSource)
        let sleepSummary = snapshot.sleepSummaryForRecovery

        return ImmersiveRecoverySummary(
            atmosphere: buildAtmosphere(
                conditionScore: snapshot.conditionScore,
                sleepJourney: sleepJourney
            ),
            recoverySession: buildRecoverySession(
                conditionScore: snapshot.conditionScore,
                sleepSummary: sleepSummary
            ),
            sleepJourney: sleepJourney,
            generatedAt: generatedAt,
            message: buildMessage(for: snapshot)
        )
    }

    private func buildAtmosphere(
        conditionScore: ConditionScore?,
        sleepJourney: ImmersiveRecoverySummary.SleepJourney
    ) -> ImmersiveRecoverySummary.Atmosphere {
        if let conditionScore {
            switch conditionScore.score {
            case 90...100:
                return .init(
                    preset: .sunrise,
                    score: conditionScore.score,
                    title: String(localized: "Clear recovery window"),
                    subtitle: conditionScore.narrativeMessage
                )
            case 70...89:
                return .init(
                    preset: .clouded,
                    score: conditionScore.score,
                    title: String(localized: "Balanced recovery field"),
                    subtitle: conditionScore.narrativeMessage
                )
            case 50...69:
                return .init(
                    preset: .mist,
                    score: conditionScore.score,
                    title: String(localized: "Gentle recovery mode"),
                    subtitle: conditionScore.narrativeMessage
                )
            default:
                return .init(
                    preset: .storm,
                    score: conditionScore.score,
                    title: String(localized: "Recovery first"),
                    subtitle: conditionScore.narrativeMessage
                )
            }
        }

        if sleepJourney.hasData {
            return .init(
                preset: sleepJourney.isHistorical ? .clouded : .mist,
                score: nil,
                title: String(localized: "Sleep-led recovery view"),
                subtitle: String(localized: "Condition score is unavailable, so DUNE is adapting the atmosphere from your latest sleep.")
            )
        }

        return .init(
            preset: .mist,
            score: nil,
            title: String(localized: "Recovery Atmosphere"),
            subtitle: String(localized: "Condition score will sharpen this space after the next successful sync.")
        )
    }

    private func buildRecoverySession(
        conditionScore: ConditionScore?,
        sleepSummary: SleepSummary?
    ) -> ImmersiveRecoverySummary.RecoverySession {
        let totalSleepMinutes = sleepSummary?.totalSleepMinutes
        let deepSleepRatio = sleepSummary?.deepSleepRatio
        let score = conditionScore?.score ?? 65
        let needsRestoreFromSleep = {
            guard let totalSleepMinutes, let deepSleepRatio else { return false }
            return totalSleepMinutes < 330 || deepSleepRatio < 0.12
        }()
        let needsRebalanceFromSleep = {
            guard let totalSleepMinutes else { return false }
            return totalSleepMinutes < 420
        }()

        if score < 50 || needsRestoreFromSleep {
            return .init(
                recommendation: .restore,
                title: String(localized: "Recovery first"),
                subtitle: String(localized: "Longer exhales and brief holds can help slow things down before your next training block."),
                cadence: .init(inhaleSeconds: 4, inhaleHoldSeconds: 2, exhaleSeconds: 6, exhaleHoldSeconds: 2, cycles: 8),
                suggestedDurationMinutes: 6,
                shouldPersistMindfulSession: true
            )
        }

        if score < 75 || needsRebalanceFromSleep {
            return .init(
                recommendation: .rebalance,
                title: String(localized: "Reset your rhythm"),
                subtitle: String(localized: "A short guided cadence can smooth out a fair or slightly elevated recovery day."),
                cadence: .init(inhaleSeconds: 4, inhaleHoldSeconds: 1, exhaleSeconds: 6, exhaleHoldSeconds: 1, cycles: 6),
                suggestedDurationMinutes: 5,
                shouldPersistMindfulSession: true
            )
        }

        return .init(
            recommendation: .sustain,
            title: String(localized: "Stay steady"),
            subtitle: String(localized: "Use a lighter cadence to hold onto today's strong recovery momentum."),
            cadence: .init(inhaleSeconds: 4, inhaleHoldSeconds: 0, exhaleSeconds: 5, exhaleHoldSeconds: 0, cycles: 5),
            suggestedDurationMinutes: 4,
            shouldPersistMindfulSession: true
        )
    }

    private func buildSleepJourney(
        from source: SleepSource
    ) -> ImmersiveRecoverySummary.SleepJourney {
        let sortedStages = source.stages.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }
            return lhs.endDate < rhs.endDate
        }

        let compressedStages = compressedSleepStages(from: sortedStages)
            .filter { $0.stage != .unspecified && $0.durationMinutes > 0 }

        let totalMinutes = compressedStages.reduce(0.0) { $0 + $1.durationMinutes }

        guard totalMinutes > 0 else {
            return .init(
                title: String(localized: "Sleep Journey"),
                subtitle: String(localized: "Sleep stages will appear after your next synced night."),
                date: source.date,
                isHistorical: source.isHistorical,
                totalMinutes: 0,
                segments: []
            )
        }

        var elapsedMinutes = 0.0
        let segments = compressedStages.map { stage in
            let startProgress = elapsedMinutes / totalMinutes
            elapsedMinutes += stage.durationMinutes
            let endProgress = elapsedMinutes / totalMinutes
            return ImmersiveRecoverySummary.SleepJourney.Segment(
                stage: stage.stage,
                durationMinutes: stage.durationMinutes,
                startProgress: startProgress,
                endProgress: endProgress
            )
        }

        let subtitle: String
        if source.isHistorical {
            subtitle = String(localized: "Showing your latest synced night because today's sleep stages aren't available yet.")
        } else {
            subtitle = String(localized: "Walk through your latest sleep stages from awake to deep recovery.")
        }

        return .init(
            title: String(localized: "Sleep Journey"),
            subtitle: subtitle,
            date: source.date,
            isHistorical: source.isHistorical,
            totalMinutes: totalMinutes,
            segments: segments
        )
    }

    private func buildMessage(for snapshot: SharedHealthSnapshot) -> String? {
        let conditionSources: Set<SharedHealthSnapshot.Source> = [.hrvSamples, .todayRHR, .yesterdayRHR, .latestRHR]
        let sleepSources: Set<SharedHealthSnapshot.Source> = [.todaySleepStages, .latestSleepStages, .sleepDailyDurations]

        let conditionFailed = !snapshot.failedSources.isDisjoint(with: conditionSources)
        let sleepFailed = !snapshot.failedSources.isDisjoint(with: sleepSources)

        if conditionFailed && sleepFailed {
            return String(localized: "Some condition and sleep sources are unavailable. DUNE is using fallback guidance.")
        }
        if conditionFailed {
            return String(localized: "Condition inputs are partially unavailable. Atmosphere is using fallback guidance.")
        }
        if sleepFailed {
            return String(localized: "Sleep stage inputs are partially unavailable. Journey mode may be simplified.")
        }

        return nil
    }

    private func resolvedSleepSource(from snapshot: SharedHealthSnapshot) -> SleepSource {
        let calendar = Calendar.current
        if !snapshot.todaySleepStages.isEmpty {
            return SleepSource(
                stages: snapshot.todaySleepStages,
                date: calendar.startOfDay(for: snapshot.fetchedAt),
                isHistorical: false
            )
        }

        if let latestSleepStages = snapshot.latestSleepStages {
            return SleepSource(
                stages: latestSleepStages.stages,
                date: latestSleepStages.date,
                isHistorical: true
            )
        }

        return SleepSource(stages: [], date: nil, isHistorical: false)
    }

    private func compressedSleepStages(
        from stages: [SleepStage]
    ) -> [(stage: SleepStage.Stage, durationMinutes: Double)] {
        var result: [(stage: SleepStage.Stage, durationMinutes: Double)] = []

        for stage in stages {
            let durationMinutes = max(stage.duration / 60.0, 0)
            guard durationMinutes > 0 else { continue }

            if let lastIndex = result.indices.last, result[lastIndex].stage == stage.stage {
                result[lastIndex].durationMinutes += durationMinutes
            } else {
                result.append((stage: stage.stage, durationMinutes: durationMinutes))
            }
        }

        return result
    }
}

private struct SleepSource: Sendable {
    let stages: [SleepStage]
    let date: Date?
    let isHistorical: Bool
}
