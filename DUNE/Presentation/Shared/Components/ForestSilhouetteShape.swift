import SwiftUI

/// Mountain/forest silhouette Shape for the Forest Green theme.
///
/// Generates a ridge-line profile using:
/// - Base sine wave for primary mountain contour
/// - 3rd harmonic for rugged peaks
/// - Triangle pulse for occasional tree-top silhouettes
/// - Pre-computed edge noise for ukiyo-e washi (和紙) edge texture
///
/// Uses shared `WaveSamples` for point pre-computation.
/// `edgeNoise` is a static constant (depends only on sampleCount).
struct ForestSilhouetteShape: Shape {
    /// Mountain height as a fraction of the rect height (0…1).
    let amplitude: CGFloat
    /// Number of full ridge periods across the rect width.
    let frequency: CGFloat
    /// Phase offset in radians (0…2π). Animatable for drift effect.
    var phase: CGFloat
    /// Vertical center of the ridge as a fraction of the rect height (0…1).
    let verticalOffset: CGFloat
    /// Peak irregularity (0 = smooth hills, 1 = rugged mountains).
    let ruggedness: CGFloat
    /// Tree silhouette density on ridge line (0 = none, 1 = dense).
    let treeDensity: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    /// Deterministic pseudo-random edge noise for washi edge effect.
    /// Product of two incommensurate sines — repeatable across launches.
    /// Depends only on sampleCount, so computed once as a static constant.
    private static let edgeNoise: [CGFloat] = (0...WaveSamples.sampleCount).map { i in
        let d = Double(i)
        return CGFloat(sin(d * 7.3 + 2.1) * sin(d * 13.7 + 5.3))
    }

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 1.5,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        ruggedness: CGFloat = 0.3,
        treeDensity: CGFloat = 0
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.ruggedness = ruggedness
        self.treeDensity = treeDensity
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset
        let edgeScale: CGFloat = 2.0 // max ±2pt edge roughness

        var path = Path()
        for (i, pt) in samples.points.enumerated() {
            let x = pt.x * rect.width
            let angle = pt.angle + phase

            // Base ridge contour
            var y = sin(angle)

            // 3rd harmonic for rugged peaks
            y += ruggedness * 0.4 * sin(3 * angle + 1.2)

            // Triangle pulse for tree-top silhouettes
            if treeDensity > 0 {
                let treePulse = Self.trianglePulse(angle: angle)
                y += treeDensity * 0.3 * treePulse
            }

            let yPos = centerY + amp * y + Self.edgeNoise[i] * edgeScale

            if i == 0 {
                path.move(to: CGPoint(x: x, y: yPos))
            } else {
                path.addLine(to: CGPoint(x: x, y: yPos))
            }
        }

        // Close area to bottom of rect for fill
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }

    /// Periodic triangle pulse: sharp upward spikes at regular intervals.
    /// Simulates tree-top silhouettes on the ridge line.
    private static func trianglePulse(angle: CGFloat) -> CGFloat {
        let sharpness: CGFloat = 8.0
        // Modulo 2π, then create a sharp triangle centered around π
        let wrapped = angle.truncatingRemainder(dividingBy: 2 * .pi)
        let normalized = abs(wrapped - .pi) / .pi  // 0 at π, 1 at 0/2π
        let pulse = Swift.max(0, 1.0 - normalized * sharpness)
        return -pulse  // Negative = upward (toward top of screen)
    }
}
