import SwiftUI

/// Asymmetric ocean-wave Shape with harmonic enrichment.
///
/// Combines a primary sine with a second harmonic to create sharp crests and
/// gentle troughs — matching real ocean wave silhouettes.
///
/// Formula: `y = A × [sin(θ + phase) + steepness × sin(2θ + phase + harmonicOffset)]`
///
/// Pre-computes normalised angles at init; `path(in:)` only evaluates
/// two `sin()` calls per sample point and scales to rect.
struct OceanWaveShape: Shape {
    /// Wave height as a fraction of the rect height (0…1).
    let amplitude: CGFloat
    /// Number of full sine periods across the rect width.
    let frequency: CGFloat
    /// Phase offset in radians (0…2π). Animatable for drift effect.
    var phase: CGFloat
    /// Vertical center of the wave as a fraction of the rect height (0…1).
    let verticalOffset: CGFloat
    /// Sharpness of wave crests (0 = pure sine, 0.3–0.4 = realistic ocean).
    let steepness: CGFloat
    /// Phase offset for the second harmonic (radians).
    let harmonicOffset: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let points: [(x: CGFloat, angle: CGFloat)]
    private static let sampleCount = 120

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 2,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.5,
        steepness: CGFloat = 0.3,
        harmonicOffset: CGFloat = .pi / 4
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.steepness = steepness
        self.harmonicOffset = harmonicOffset

        let count = Self.sampleCount
        var pts: [(x: CGFloat, angle: CGFloat)] = []
        pts.reserveCapacity(count + 1)
        for i in 0...count {
            let x = CGFloat(i) / CGFloat(count)
            let angle = x * frequency * 2 * .pi
            pts.append((x: x, angle: angle))
        }
        self.points = pts
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var path = Path()
        for (i, pt) in points.enumerated() {
            let primary = sin(pt.angle + phase)
            let harmonic = steepness * sin(2 * pt.angle + phase + harmonicOffset)
            let x = pt.x * rect.width
            let y = centerY + amp * (primary + harmonic)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Close area to bottom of rect for fill
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Ocean Wave Overlay (Multi-speed, Directional)

/// Animated ocean wave overlay with configurable drift speed and direction.
struct OceanWaveOverlayView: View {
    var color: Color
    var opacity: Double
    var amplitude: CGFloat
    var frequency: CGFloat
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0
    var steepness: CGFloat = 0.3
    var harmonicOffset: CGFloat = .pi / 4
    /// Duration of one full phase cycle (seconds). Slower = more distant wave.
    var driftDuration: TimeInterval = 6
    /// Drift direction. Reverse creates cross-current depth effect.
    var reverseDirection: Bool = false

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OceanWaveShape(
            amplitude: amplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset,
            steepness: steepness,
            harmonicOffset: harmonicOffset
        )
        .fill(color.opacity(opacity))
        .mask {
            if bottomFade > 0 {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 1.0 - bottomFade),
                        .init(color: .white.opacity(0), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle()
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion else { return }
            let target: CGFloat = reverseDirection ? -(2 * .pi) : (2 * .pi)
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = target
            }
        }
    }
}
