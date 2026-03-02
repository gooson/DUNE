import SwiftUI

/// Cherry branch silhouette stroke shape for Sakura theme.
///
/// Uses a primary branch curve plus short twig offsets to avoid generic wave feel.
struct SakuraBranchShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat
    let twigDensity: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    init(
        amplitude: CGFloat = 0.08,
        frequency: CGFloat = 1.2,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.72,
        twigDensity: CGFloat = 0.35
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.twigDensity = twigDensity
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var ridgePoints: [CGPoint] = []
        ridgePoints.reserveCapacity(samples.points.count)

        for pt in samples.points {
            let x = pt.x * rect.width
            let angle = pt.angle + phase
            var y = sin(angle)
            y += 0.22 * sin(0.62 * angle + 1.1)
            y += 0.08 * sin(2.3 * angle + 0.4)

            ridgePoints.append(CGPoint(x: x, y: centerY + amp * y))
        }

        var path = Path()
        for (idx, point) in ridgePoints.enumerated() {
            if idx == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        let strideCount = max(4, Int(11 - twigDensity * 7))
        if strideCount > 0 {
            for idx in stride(from: 4, to: ridgePoints.count - 4, by: strideCount) {
                let base = ridgePoints[idx]
                let twigLength = amp * (0.28 + twigDensity * 0.38)
                let twigAngle = CGFloat(idx).truncatingRemainder(dividingBy: 2) == 0 ? -0.68 : -0.44
                let twigEnd = CGPoint(
                    x: base.x - twigLength * cos(twigAngle),
                    y: base.y + twigLength * sin(twigAngle)
                )
                path.move(to: base)
                path.addLine(to: twigEnd)
            }
        }

        return path
    }
}
