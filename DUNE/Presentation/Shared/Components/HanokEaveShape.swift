import SwiftUI

/// Dalhangari (달항아리) moon jar asymmetric wave Shape for the Hanok theme.
///
/// Generates an organic, imperfect curve inspired by the asymmetric beauty
/// of Korean moon jars using:
/// - Base sine wave for primary contour
/// - Asymmetric modulation for left/right amplitude difference
/// - 3rd harmonic for organic imperfection
/// - Wide swell for the jar's broad body feel
///
/// Uses shared `WaveSamples` for point pre-computation.
struct DalhangariWaveShape: Shape {
    /// Wave height as a fraction of the rect height (0…1).
    let amplitude: CGFloat
    /// Number of full wave periods across the rect width.
    let frequency: CGFloat
    /// Phase offset in radians (0…2π). Animatable for drift effect.
    var phase: CGFloat
    /// Vertical center of the wave as a fraction of the rect height (0…1).
    let verticalOffset: CGFloat
    /// Asymmetry intensity (0 = symmetric, 0.5 = strongly asymmetric).
    let asymmetry: CGFloat
    /// Organic 3rd harmonic blend (0 = pure sine, 0.3 = visible imperfection).
    let organicBlend: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 1.5,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        asymmetry: CGFloat = 0.3,
        organicBlend: CGFloat = 0.15
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.asymmetry = Swift.min(asymmetry, 0.5)
        self.organicBlend = Swift.min(organicBlend, 0.3)
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

            // Base sine contour
            var y = sin(angle)

            // Asymmetric modulation — left/right amplitude difference
            y *= (1 + asymmetry * sin(angle / 3))

            // Organic 3rd harmonic — imperfect, handmade curve
            y += organicBlend * sin(3 * angle + phase)

            // Wide swell — moon jar's broad body
            y += 0.15 * sin(0.5 * angle + phase / 3)

            let yPos = centerY + amp * y

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
