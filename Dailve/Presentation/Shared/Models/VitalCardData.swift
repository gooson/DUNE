import Foundation

/// Identifies which section a vital card belongs to in the Wellness tab.
enum CardSection: String, Sendable {
    case physical
    case active

    static func section(for category: HealthMetric.Category) -> CardSection {
        switch category {
        case .weight, .bmi, .bodyFat, .leanBodyMass:
            return .physical
        case .hrv, .rhr, .heartRate, .sleep, .exercise, .steps,
             .spo2, .respiratoryRate, .vo2Max, .heartRateRecovery, .wristTemperature:
            return .active
        }
    }
}

struct VitalCardData: Identifiable, Hashable, Sendable {
    let id: String
    let category: HealthMetric.Category
    let section: CardSection
    let title: String
    let value: String
    let unit: String
    let change: String?
    let changeIsPositive: Bool?
    let sparklineData: [Double]
    let metric: HealthMetric
    let lastUpdated: Date
    let isStale: Bool

    static func == (lhs: VitalCardData, rhs: VitalCardData) -> Bool {
        lhs.id == rhs.id && lhs.value == rhs.value && lhs.lastUpdated == rhs.lastUpdated
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(value)
        hasher.combine(lastUpdated)
    }
}
