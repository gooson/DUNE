import SwiftUI

/// Soft blossom silhouette Shape for Sakura Calm theme.
///
/// Builds a petal-cluster ridge profile distinct from Forest/Ocean wave language.
struct SakuraPetalShape: Shape {
    /// Ridge height as fraction of rect height (0...1).
    let amplitude: CGFloat
    /// Number of periods across rect width.
    let frequency: CGFloat
    /// Horizontal phase offset (animatable).
    var phase: CGFloat
    /// Baseline vertical position as fraction of rect height.
    let verticalOffset: CGFloat
    /// Blossom prominence factor (0 = smooth band, higher = petal peaks).
    let petalDensity: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    /// Soft paper-edge noise for natural hand-drawn silhouette feel.
    private static let edgeNoise: [CGFloat] = (0...WaveSamples.sampleCount).map { i in
        let d = Double(i)
        let octave1 = sin(d * 5.3 + 0.9) * sin(d * 9.7 + 2.5)
        let octave2 = 0.35 * sin(d * 16.3 + 1.2) * sin(d * 24.1 + 4.1)
        return CGFloat(octave1 + octave2) / 1.35
    }

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 1.6,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.55,
        petalDensity: CGFloat = 0
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.petalDensity = petalDensity
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset
        let edgeScale: CGFloat = 1.0

        var path = Path()
        for (i, pt) in samples.points.enumerated() {
            let x = pt.x * rect.width
            let angle = pt.angle + phase

            var y = 0.78 * sin(angle)
            y += 0.16 * sin(0.58 * angle + 0.7)
            y += 0.05 * sin(2.6 * angle + 0.9)

            if petalDensity > 0 {
                y += petalDensity * Self.blossomCluster(angle: angle)
            }

            let roughness = 0.32 + petalDensity * 0.22
            let yPos = centerY + amp * y + Self.edgeNoise[i] * edgeScale * roughness

            if i == 0 {
                path.move(to: CGPoint(x: x, y: yPos))
            } else {
                path.addLine(to: CGPoint(x: x, y: yPos))
            }
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }

    /// Rounded flower-cluster pulses (upward) with slight secondary cadence.
    private static func blossomCluster(angle: CGFloat) -> CGFloat {
        let major = pow(max(0, sin(angle * 1.95 + 0.35)), 2.9)
        let minor = pow(max(0, sin(angle * 3.4 + 1.15)), 3.2)
        return (-0.22 * major) - (0.08 * minor)
    }
}
