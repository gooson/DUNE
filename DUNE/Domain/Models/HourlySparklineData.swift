import Foundation

/// Lightweight sparkline data for hourly score display on hero cards.
struct HourlySparklineData: Sendable, Equatable {
    let points: [HourlyPoint]
    let currentScore: Double
    let previousScore: Double?
    /// Whether this sparkline includes data points from yesterday (rolling 24h window).
    let includesYesterday: Bool

    struct HourlyPoint: Sendable, Equatable, Identifiable {
        let index: Int   // Sequential position for chart x-axis (0-based)
        let hour: Int    // Clock hour (0-23)
        let score: Double
        var id: Int { index }
    }

    /// Delta from previous snapshot to current.
    var delta: Double {
        guard let previous = previousScore else { return 0 }
        return currentScore - previous
    }

    var deltaDirection: DeltaDirection {
        let threshold = 2.0
        if delta > threshold { return .up }
        if delta < -threshold { return .down }
        return .stable
    }

    static let empty = HourlySparklineData(points: [], currentScore: 0, previousScore: nil, includesYesterday: false)

    /// Returns self if non-empty, nil otherwise. Eliminates repeated `.points.isEmpty ? nil : self` at call sites.
    var nonEmptyOrNil: HourlySparklineData? {
        points.isEmpty ? nil : self
    }
}

enum DeltaDirection: Sendable, Equatable {
    case up, down, stable
}

/// Identifies which score type a sparkline represents.
enum ScoreType: String, Sendable {
    case condition
    case wellness
    case readiness
}
