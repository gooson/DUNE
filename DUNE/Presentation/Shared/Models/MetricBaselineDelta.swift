import Foundation

/// Baseline comparison deltas for a single metric value.
struct MetricBaselineDelta: Sendable {
    let yesterdayDelta: Double?
    let shortTermDelta: Double?
    let longTermDelta: Double?

    var hasAnyValue: Bool {
        yesterdayDelta != nil || shortTermDelta != nil || longTermDelta != nil
    }

    var preferredDetail: BaselineDetail? {
        if let yesterdayDelta {
            return BaselineDetail(label: String(localized: "vs yesterday"), value: yesterdayDelta)
        }
        if let shortTermDelta {
            return BaselineDetail(label: String(localized: "vs 14d avg"), value: shortTermDelta)
        }
        if let longTermDelta {
            return BaselineDetail(label: String(localized: "vs 60d avg"), value: longTermDelta)
        }
        return nil
    }
}

struct BaselineDetail: Sendable {
    let label: String
    let value: Double
    let fractionDigits: Int

    init(label: String, value: Double, fractionDigits: Int = 1) {
        self.label = label
        self.value = value
        self.fractionDigits = fractionDigits
    }
}
