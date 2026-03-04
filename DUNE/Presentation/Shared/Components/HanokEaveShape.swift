import SwiftUI

/// Korean traditional eave (처마) Shape for the Hanok theme.
///
/// Generates a giwa (기와) rooftop profile using:
/// - Base sine wave for primary eave contour
/// - 2nd harmonic for the characteristic eave-tip uplift (추녀)
/// - Optional tile ripple for giwa (기와) surface texture
/// - Pre-computed edge noise for organic clay-tile variation
///
/// Uses shared `WaveSamples` for point pre-computation.
struct HanokEaveShape: Shape {
    /// Eave height as a fraction of the rect height (0…1).
    let amplitude: CGFloat
    /// Number of full eave periods across the rect width.
    let frequency: CGFloat
    /// Phase offset in radians (0…2π). Animatable for drift effect.
    var phase: CGFloat
    /// Vertical center of the eave as a fraction of the rect height (0…1).
    let verticalOffset: CGFloat
    /// Eave-tip uplift intensity (0 = flat, 0.4 = pronounced Korean eave curve).
    let uplift: CGFloat
    /// Tile ripple intensity (0 = smooth, 1 = visible giwa texture).
    let tileRipple: CGFloat
    /// Tile ripple frequency multiplier.
    let tileFrequency: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    /// Deterministic pseudo-random edge noise for organic giwa edge.
    /// Gentler than desert/forest — clay tiles have smoother edges.
    private static let edgeNoise: [CGFloat] = (0...WaveSamples.sampleCount).map { i in
        let d = Double(i)
        return CGFloat(sin(d * 4.3 + 1.7) * sin(d * 9.1 + 2.9)) * 0.6
    }

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 1.5,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        uplift: CGFloat = 0.2,
        tileRipple: CGFloat = 0,
        tileFrequency: CGFloat = 8.0
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.uplift = Swift.min(uplift, 0.4)
        self.tileRipple = Swift.min(tileRipple, 0.15)
        self.tileFrequency = tileFrequency
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var path = Path()
        for (i, pt) in samples.points.enumerated() {
            let x = pt.x * rect.width
            let angle = pt.angle + phase

            // Base eave contour
            var y = sin(angle)

            // 2nd harmonic for eave-tip uplift (추녀 곡선)
            // Negative contribution lifts the curve upward at periodic intervals
            y -= uplift * sin(2 * angle + .pi / 3)

            // Broad swell for rounded roof mass
            y += 0.15 * sin(0.5 * angle + 0.6)

            // High-frequency tile ripple on surface (기와 골)
            if tileRipple > 0 {
                let tileAngle = pt.x * tileFrequency * frequency * 2 * .pi
                y += tileRipple * 0.1 * sin(tileAngle + phase * 1.2)
            }

            let yPos = centerY + amp * y + Self.edgeNoise[i] * 1.5

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
