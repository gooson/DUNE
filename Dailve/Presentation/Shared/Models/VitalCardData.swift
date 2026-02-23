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
    let baselineDetail: BaselineDetail?
    let inversePolarity: Bool

    init(
        id: String,
        category: HealthMetric.Category,
        section: CardSection,
        title: String,
        value: String,
        unit: String,
        change: String?,
        changeIsPositive: Bool?,
        sparklineData: [Double],
        metric: HealthMetric,
        lastUpdated: Date,
        isStale: Bool,
        baselineDetail: BaselineDetail? = nil,
        inversePolarity: Bool = false
    ) {
        self.id = id
        self.category = category
        self.section = section
        self.title = title
        self.value = value
        self.unit = unit
        self.change = change
        self.changeIsPositive = changeIsPositive
        self.sparklineData = sparklineData
        self.metric = metric
        self.lastUpdated = lastUpdated
        self.isStale = isStale
        self.baselineDetail = baselineDetail
        self.inversePolarity = inversePolarity
    }

    static func == (lhs: VitalCardData, rhs: VitalCardData) -> Bool {
        lhs.id == rhs.id
            && lhs.value == rhs.value
            && lhs.lastUpdated == rhs.lastUpdated
            && lhs.inversePolarity == rhs.inversePolarity
            && lhs.baselineDetail?.label == rhs.baselineDetail?.label
            && lhs.baselineDetail?.value == rhs.baselineDetail?.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(value)
        hasher.combine(lastUpdated)
        hasher.combine(inversePolarity)
        hasher.combine(baselineDetail?.label)
        hasher.combine(baselineDetail?.value)
    }
}
