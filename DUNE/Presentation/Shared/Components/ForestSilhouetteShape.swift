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
    /// Tree silhouette density (0 = bare hills, higher = denser canopy).
    let treeDensity: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    /// 3-octave fBm edge noise for washi (和紙) edge texture.
    /// Layered incommensurate sine products at doubling frequencies / halving amplitudes
    /// produce self-similar, fractal-like roughness — more organic than single-octave noise.
    /// Depends only on sampleCount, so computed once as a static constant.
    private static let edgeNoise: [CGFloat] = (0...WaveSamples.sampleCount).map { i in
        let d = Double(i)
        let octave1 = sin(d * 7.3 + 2.1) * sin(d * 13.7 + 5.3)         // broad contour
        let octave2 = 0.5 * sin(d * 23.1 + 0.7) * sin(d * 31.9 + 4.1)  // mid detail
        let octave3 = 0.25 * sin(d * 53.7 + 3.2) * sin(d * 71.3 + 1.8) // fine grain
        return CGFloat(octave1 + octave2 + octave3) / 1.75
    }

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 1.5,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        treeDensity: CGFloat = 0
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.treeDensity = treeDensity
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset
        // Edge noise scale — amplifies fBm texture relative to base sine amplitude.
        let edgeScale: CGFloat = 2.1

        var path = Path()
        for (i, pt) in samples.points.enumerated() {
            let x = pt.x * rect.width
            let angle = pt.angle + phase

            // Base ridge contour
            var y = sin(angle)

            // Broad canopy swell for rounded forest masses (0.245 = 0.7 × 0.35).
            y += 0.245 * sin(0.55 * angle + 0.8)

            // Mid harmonic for irregular ridge rhythm (0.078 = 0.3 × 0.26).
            y += 0.078 * sin(2.2 * angle + 1.1)

            // Rounded canopy pulse for tree-top silhouettes.
            if treeDensity > 0 {
                let treePulse = Self.canopyPulse(angle: angle * 0.9)
                y += treeDensity * 0.32 * treePulse
            }

            // Tree cluster modulation: 0.6 = roughness depth, 1.3 = cluster spacing frequency.
            let treeModulation: CGFloat = 1.0 + treeDensity * 0.6 * abs(sin(angle * 1.3))
            let yPos = centerY + amp * y + Self.edgeNoise[i] * edgeScale * treeModulation

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
