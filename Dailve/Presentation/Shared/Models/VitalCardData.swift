import Foundation

struct VitalCardData: Identifiable, Hashable, Sendable {
    let id: String
    let category: HealthMetric.Category
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
