import Foundation
import Testing
@testable import DUNE

@Suite("ImmersiveRecoverySummary")
struct ImmersiveRecoverySummaryTests {
    @Test("breathing cadence totals inhale hold exhale hold seconds")
    func totalCycleSeconds() {
        let cadence = BreathingCadence(
            inhaleSeconds: 4,
            inhaleHoldSeconds: 1,
            exhaleSeconds: 6,
            exhaleHoldSeconds: 2,
            cycles: 8
        )

        #expect(cadence.totalCycleSeconds == 13)
    }

    @Test("sleep journey hasData reflects whether segments exist")
    func sleepJourneyHasData() {
        let emptyJourney = ImmersiveRecoverySummary.SleepJourney(
            title: "Sleep Journey",
            subtitle: "No data",
            date: nil,
            isHistorical: false,
            totalMinutes: 0,
            segments: []
        )
        let populatedJourney = ImmersiveRecoverySummary.SleepJourney(
            title: "Sleep Journey",
            subtitle: "Has data",
            date: Date(),
            isHistorical: false,
            totalMinutes: 90,
            segments: [
                .init(stage: .core, durationMinutes: 90, startProgress: 0, endProgress: 1)
            ]
        )

        #expect(emptyJourney.hasData == false)
        #expect(populatedJourney.hasData == true)
    }

    @Test("summary hasAnyData is true when score or sleep journey is present")
    func hasAnyData() {
        let generatedAt = Date()
        let emptySummary = makeSummary(generatedAt: generatedAt, score: nil, segments: [])
        let scoreSummary = makeSummary(generatedAt: generatedAt, score: 76, segments: [])
        let sleepSummary = makeSummary(
            generatedAt: generatedAt,
            score: nil,
            segments: [.init(stage: .deep, durationMinutes: 50, startProgress: 0, endProgress: 1)]
        )

        #expect(emptySummary.hasAnyData == false)
        #expect(scoreSummary.hasAnyData == true)
        #expect(sleepSummary.hasAnyData == true)
    }

    private func makeSummary(
        generatedAt: Date,
        score: Int?,
        segments: [ImmersiveRecoverySummary.SleepJourney.Segment]
    ) -> ImmersiveRecoverySummary {
        ImmersiveRecoverySummary(
            atmosphere: .init(
                preset: .mist,
                score: score,
                title: "Recovery Atmosphere",
                subtitle: "Fallback"
            ),
            recoverySession: .init(
                recommendation: .rebalance,
                title: "Reset your rhythm",
                subtitle: "Guided cadence",
                cadence: .init(inhaleSeconds: 4, inhaleHoldSeconds: 1, exhaleSeconds: 6, exhaleHoldSeconds: 1, cycles: 6),
                suggestedDurationMinutes: 5,
                shouldPersistMindfulSession: true
            ),
            sleepJourney: .init(
                title: "Sleep Journey",
                subtitle: "Latest sleep",
                date: nil,
                isHistorical: false,
                totalMinutes: segments.reduce(0) { $0 + $1.durationMinutes },
                segments: segments
            ),
            generatedAt: generatedAt,
            message: nil
        )
    }
}
