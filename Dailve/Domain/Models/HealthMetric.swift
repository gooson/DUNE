import Foundation

struct HealthMetric: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let value: Double
    let unit: String
    let change: Double?
    let date: Date
    let category: Category
    var isHistorical: Bool = false
    var iconOverride: String? = nil

    enum Category: String, Sendable, CaseIterable {
        case hrv
        case rhr
        case sleep
        case exercise
        case steps
        case weight
    }

    var changeSignificance: Double {
        guard let change else { return 0 }
        return abs(change)
    }
}

struct SleepStage: Sendable {
    let stage: Stage
    let duration: TimeInterval
    let startDate: Date
    let endDate: Date

    enum Stage: String, Sendable {
        case awake
        case core
        case deep
        case rem

        var label: String {
            switch self {
            case .awake: "Awake"
            case .core: "Core"
            case .deep: "Deep"
            case .rem: "REM"
            }
        }
    }
}

struct HRVSample: Sendable {
    let value: Double
    let date: Date
}

struct WorkoutSummary: Identifiable, Sendable {
    let id: String
    let type: String
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let date: Date
}
