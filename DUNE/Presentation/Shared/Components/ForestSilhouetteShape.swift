import SwiftUI

/// Mountain/forest silhouette Shape for the Forest Green theme.
///
/// Generates a ridge-line profile using:
/// - Base sine wave for primary mountain contour
/// - Low-frequency canopy swell for rounded "mongle" silhouettes
/// - Mid harmonic for irregular forest ridges
/// - Rounded canopy pulse for treetop clusters
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
        let edgeScale: CGFloat = 2.1 // larger local noise while keeping base amplitude unchanged

        var path = Path()
        for (i, pt) in samples.points.enumerated() {
            let x = pt.x * rect.width
            let angle = pt.angle + phase

            // Base ridge contour
            var y = sin(angle)

            // Broad canopy swell for rounded forest masses.
            y += (1 - ruggedness) * 0.35 * sin(0.55 * angle + 0.8)

            // Mid harmonic for irregular ridge rhythm (less sharp than dune/ocean crests).
            y += ruggedness * 0.26 * sin(2.2 * angle + 1.1)

            // Rounded canopy pulse for tree-top silhouettes.
            if treeDensity > 0 {
                let treePulse = Self.canopyPulse(angle: angle * 0.9)
                y += treeDensity * 0.32 * treePulse
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

    /// Periodic rounded pulse for clustered tree canopies.
    private static func canopyPulse(angle: CGFloat) -> CGFloat {
        let normalized = 0.5 + 0.5 * sin(angle * 2.0)
        let rounded = pow(normalized, 1.8)
        return -rounded // Negative = upward (toward top of screen)
    }
}
