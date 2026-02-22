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
            return BaselineDetail(label: "vs yesterday", value: yesterdayDelta)
        }
        if let shortTermDelta {
            return BaselineDetail(label: "vs 14d avg", value: shortTermDelta)
        }
        if let longTermDelta {
            return BaselineDetail(label: "vs 60d avg", value: longTermDelta)
        }
        return nil
    }
}

struct BaselineDetail: Sendable {
    let label: String
    let value: Double
}
