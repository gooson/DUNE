import SwiftUI
import Charts

/// Compact sparkline chart showing today's hourly score progression.
/// Used on hero cards alongside the score ring.
struct HourlySparklineView: View {
    let data: HourlySparklineData
    let tintColor: Color

    private enum Layout {
        static let height: CGFloat = 32
    }

    var body: some View {
        if data.points.isEmpty {
            Rectangle()
                .fill(.clear)
                .frame(height: Layout.height)
        } else {
            Chart(data.points, id: \.hour) { point in
                LineMark(
                    x: .value("Hour", point.hour),
                    y: .value("Score", point.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(tintColor)

                AreaMark(
                    x: .value("Hour", point.hour),
                    y: .value("Score", point.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(areaGradient)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 0...23)
            .chartYScale(domain: computedYDomain)
            .frame(height: Layout.height)
            .clipped()
        }
    }

    // MARK: - Cached Computations

    /// Hoisted gradient to avoid allocation inside Chart closure body.
    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [tintColor.opacity(0.3), tintColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Y-axis domain computed once per body evaluation.
    private var computedYDomain: ClosedRange<Double> {
        let scores = data.points.map(\.score)
        let minScore = (scores.min() ?? 0) - 5
        let maxScore = (scores.max() ?? 100) + 5
        return max(0, minScore)...min(100, maxScore)
    }
}
