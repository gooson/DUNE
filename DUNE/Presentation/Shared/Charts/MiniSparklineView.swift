import SwiftUI

/// Minimal sparkline for metric cards — renders a simple path with no axes.
struct MiniSparklineView: View {
    let dataPoints: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let linePath = linePath(in: geometry.size)
            let areaPath = areaPath(in: geometry.size)

            areaPath
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.15), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            linePath
                .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard dataPoints.count >= 2 else { return [] }

        let minVal = dataPoints.min() ?? 0
        let maxVal = dataPoints.max() ?? 1
        let range = max(maxVal - minVal, 0.01)
        let stepX = size.width / CGFloat(dataPoints.count - 1)

        return dataPoints.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let y = size.height - ((CGFloat(value - minVal) / CGFloat(range)) * size.height)
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(in size: CGSize) -> Path {
        let pts = points(in: size)
        var path = Path()
        for (i, pt) in pts.enumerated() {
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }

    private func areaPath(in size: CGSize) -> Path {
        var path = linePath(in: size)
        guard !path.isEmpty else { return path }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}
