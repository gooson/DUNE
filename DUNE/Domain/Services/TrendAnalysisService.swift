import Foundation

/// Analyzes time-series health data to detect directional trends.
///
/// Uses a simple consecutive-direction approach:
/// 3+ consecutive days in the same direction → rising/falling.
/// Otherwise stable or volatile.
struct TrendAnalysisService: Sendable {

    /// Minimum data points required for trend analysis
    private static let minimumDataPoints = 3

    /// Analyze trend direction from daily values.
    /// - Parameters:
    ///   - values: Daily (date, value) pairs. Need not be sorted.
    ///   - windowDays: How many recent days to consider. Default 7.
    /// - Returns: A `TrendAnalysis` with direction, consecutive days, and change percent.
    func analyzeTrend(
        values: [(date: Date, value: Double)],
        windowDays: Int = 7
    ) -> TrendAnalysis {
        guard values.count >= Self.minimumDataPoints else {
            return .insufficient
        }

        // Sort oldest-first (Correction #156)
        let sorted = values.sorted { $0.date < $1.date }

        // Limit to recent window
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -windowDays, to: Date()
        ) ?? Date()
        let recent = sorted.filter { $0.date >= cutoff }

        guard recent.count >= Self.minimumDataPoints else {
            return .insufficient
        }

        // Compute daily deltas
        var deltas: [Double] = []
        for i in 1..<recent.count {
            let prev = recent[i - 1].value
            guard prev > 0, prev.isFinite else { continue }
            let delta = recent[i].value - prev
            guard delta.isFinite else { continue }
            deltas.append(delta)
        }

        guard !deltas.isEmpty else { return .insufficient }

        // Count consecutive direction from most recent
        let lastDelta = deltas.last ?? 0
        let isLastRising = lastDelta > 0

        var consecutive = 0
        for delta in deltas.reversed() {
            let isRising = delta > 0
            if isRising == isLastRising {
                consecutive += 1
            } else {
                break
            }
        }

        // Overall change percent
        let firstValue = recent.first?.value ?? 0
        let lastValue = recent.last?.value ?? 0
        let changePercent: Double
        if firstValue > 0, firstValue.isFinite {
            changePercent = ((lastValue - firstValue) / firstValue) * 100
        } else {
            changePercent = 0
        }
        guard changePercent.isFinite else {
            return TrendAnalysis(direction: .volatile, consecutiveDays: 0, changePercent: 0)
        }

        // Determine direction
        let direction: TrendDirection
        if consecutive >= 3 {
            direction = isLastRising ? .rising : .falling
        } else {
            // Check for volatility: large swings
            let magnitudes = deltas.map { abs($0) }
            let avgMagnitude = magnitudes.reduce(0, +) / Double(magnitudes.count)
            let avgValue = recent.map(\.value).reduce(0, +) / Double(recent.count)
            if avgValue > 0, (avgMagnitude / avgValue) > 0.1 {
                direction = .volatile
            } else {
                direction = .stable
            }
        }

        return TrendAnalysis(
            direction: direction,
            consecutiveDays: consecutive,
            changePercent: changePercent
        )
    }
}
