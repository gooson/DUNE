import SwiftUI

/// A recent-record trend scaled to this metric's own observed values.
struct WellnessMetricSparkline: View {
    let values: [Double]
    let color: Color

    private var range: ClosedRange<Double> {
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let padding = max((high - low) * 0.12, 0.01)
        return (low - padding)...(high + padding)
    }

    var body: some View {
        GeometryReader { geometry in
            let points = chartPoints(in: geometry.size)
            if let last = points.last {
                areaPath(points: points, size: geometry.size).fill(
                    LinearGradient(
                        colors: [color.opacity(0.18), color.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                linePath(points: points)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .position(last)
            }
        }
        .accessibilityHidden(true)
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2, values.allSatisfy(\.isFinite) else { return [] }
        let lower = range.lowerBound
        let span = range.upperBound - lower
        return values.enumerated().map { index, value in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(values.count - 1),
                y: size.height * CGFloat(1 - (value - lower) / span)
            )
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        var path = linePath(points: points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

#Preview {
    WellnessMetricSparkline(values: [48, 46, 47, 43, 45], color: DS.Color.hrv)
        .frame(height: 34)
        .padding()
}
