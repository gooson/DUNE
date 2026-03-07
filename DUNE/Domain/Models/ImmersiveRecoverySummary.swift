import Foundation

enum ConditionAtmospherePreset: String, Sendable, CaseIterable {
    case sunrise
    case clouded
    case mist
    case storm
}

enum RecoveryRecommendation: String, Sendable, CaseIterable {
    case sustain
    case rebalance
    case restore
}

struct BreathingCadence: Sendable, Equatable {
    let inhaleSeconds: Int
    let inhaleHoldSeconds: Int
    let exhaleSeconds: Int
    let exhaleHoldSeconds: Int
    let cycles: Int

    var totalCycleSeconds: Int {
        inhaleSeconds + inhaleHoldSeconds + exhaleSeconds + exhaleHoldSeconds
    }
}

struct ImmersiveRecoverySummary: Sendable, Equatable {
    struct Atmosphere: Sendable, Equatable {
        let preset: ConditionAtmospherePreset
        let score: Int?
        let title: String
        let subtitle: String
    }

    struct RecoverySession: Sendable, Equatable {
        let recommendation: RecoveryRecommendation
        let title: String
        let subtitle: String
        let cadence: BreathingCadence
        let suggestedDurationMinutes: Int
        let shouldPersistMindfulSession: Bool
    }

    struct SleepJourney: Sendable, Equatable {
        struct Segment: Sendable, Equatable, Identifiable {
            let stage: SleepStage.Stage
            let durationMinutes: Double
            let startProgress: Double
            let endProgress: Double

            var id: String {
                "\(stage.rawValue)-\(startProgress)-\(endProgress)"
            }
        }

        let title: String
        let subtitle: String
        let date: Date?
        let isHistorical: Bool
        let totalMinutes: Double
        let segments: [Segment]

        var hasData: Bool {
            !segments.isEmpty
        }
    }

    let atmosphere: Atmosphere
    let recoverySession: RecoverySession
    let sleepJourney: SleepJourney
    let generatedAt: Date
    let message: String?

    var hasAnyData: Bool {
        atmosphere.score != nil || sleepJourney.hasData
    }
}
