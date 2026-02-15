import Foundation

struct HealthMetric: Identifiable, Sendable {
    let id: String
    let name: String
    let value: Double
    let unit: String
    let change: Double?
    let date: Date
    let category: Category

    enum Category: String, Sendable, CaseIterable {
        case hrv
        case rhr
        case sleep
        case exercise
        case steps
        case weight
    }

    var formattedValue: String {
        switch category {
        case .hrv:
            return String(format: "%.0fms", value)
        case .rhr:
            return String(format: "%.0fbpm", value)
        case .sleep:
            let hours = Int(value) / 60
            let minutes = Int(value) % 60
            return "\(hours)h \(minutes)m"
        case .exercise:
            return String(format: "%.0fmin", value)
        case .steps:
            return String(format: "%.0f", value)
        case .weight:
            return String(format: "%.1fkg", value)
        }
    }

    var formattedChange: String? {
        guard let change else { return nil }
        let arrow = change > 0 ? "\u{25B2}" : "\u{25BC}"
        return "\(arrow)\(String(format: "%.1f", abs(change)))"
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
