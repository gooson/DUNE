import SwiftUI

/// Asymmetric sand-dune Shape for the Desert Warm theme.
///
/// Generates a wind-sculpted dune profile using:
/// - Base sine wave for primary dune contour
/// - 2nd harmonic with skew for windward/leeward asymmetry
/// - Optional high-frequency ripple for surface sand texture
/// - Pre-computed edge noise for organic edge variation
///
/// Uses shared `WaveSamples` for point pre-computation.
struct DesertDuneShape: Shape {
    /// Dune height as a fraction of the rect height (0…1).
    let amplitude: CGFloat
    /// Number of full dune periods across the rect width.
    let frequency: CGFloat
    /// Phase offset in radians (0…2π). Animatable for drift effect.
    var phase: CGFloat
    /// Vertical center of the dune as a fraction of the rect height (0…1).
    let verticalOffset: CGFloat
    /// Windward/leeward asymmetry (0 = symmetric, 0.5 = strong asymmetry).
    let skewness: CGFloat
    /// Phase offset for the skew harmonic.
    let skewOffset: CGFloat
    /// Sand ripple intensity (0 = none, 1 = strong surface ripples).
    let ripple: CGFloat
    /// Ripple frequency multiplier relative to base frequency.
    let rippleFrequency: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples
    /// Pre-computed ripple angles (invariant across frames; only populated when ripple > 0).
    private let rippleAngles: [CGFloat]

    /// Deterministic pseudo-random edge noise for organic dune edge.
    /// Product of two incommensurate sines — repeatable across launches.
    private static let edgeNoise: [CGFloat] = (0...WaveSamples.sampleCount).map { i in
        let d = Double(i)
        return CGFloat(sin(d * 5.7 + 1.3) * sin(d * 11.3 + 3.7))
    }

    /// Phase-scaling constant for ripple drift (slightly different speed from base).
    private static let rippleDrift: CGFloat = 1.3

    /// Scale factor for edge noise variation on dune silhouette.
    private static let edgeNoiseScale: CGFloat = 1.5

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 1.5,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        skewness: CGFloat = 0.25,
        skewOffset: CGFloat = .pi / 6,
        ripple: CGFloat = 0,
        rippleFrequency: CGFloat = 6.0
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.skewness = Swift.min(skewness, 0.5)
        self.skewOffset = skewOffset
        self.ripple = Swift.min(ripple, 0.3)
        self.rippleFrequency = rippleFrequency
        self.samples = WaveSamples(frequency: frequency)

        // Pre-compute ripple angles (only phase varies per frame)
        if ripple > 0 {
            self.rippleAngles = samples.points.map { pt in
                pt.x * rippleFrequency * frequency * 2 * .pi
            }
        } else {
            self.rippleAngles = []
        }
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var path = Path()
        for (i, pt) in samples.points.enumerated() {
            let x = pt.x * rect.width
            let angle = pt.angle + phase

            // Base dune contour
            var y = sin(angle)

            // 2nd harmonic for windward/leeward asymmetry
            y += skewness * sin(2 * angle + skewOffset)

            // High-frequency sand ripple on surface (angles pre-computed in init)
            if ripple > 0 {
                y += ripple * 0.15 * sin(rippleAngles[i] + phase * Self.rippleDrift)
            }

            let yPos = centerY + amp * y + Self.edgeNoise[i] * Self.edgeNoiseScale

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
}
