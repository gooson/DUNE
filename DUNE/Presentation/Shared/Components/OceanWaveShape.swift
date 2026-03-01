import SwiftUI

/// Asymmetric ocean-wave Shape with harmonic enrichment.
///
/// Combines a primary sine with higher harmonics to create sharp crests,
/// gentle troughs, and variable wave heights — matching Japanese-style
/// ocean wave silhouettes.
///
/// Formula:
/// ```
/// y = A × [sin(θ + φ)
///        + steepness × sin(2θ + φ + offset)
///        + crestHeight × sin(0.5θ + φ × 0.3)
///        + crestSharpness × sin(3θ + φ × 1.5)]
/// ```
///
/// Pre-computes normalised angles at init; `path(in:)` only evaluates
/// four `sin()` calls per sample point and scales to rect.
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
    /// Low-frequency envelope: makes some waves taller than others (0…0.4).
    let crestHeight: CGFloat
    /// High-frequency sharpness at wave peaks (0…0.15).
    let crestSharpness: CGFloat

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
        harmonicOffset: CGFloat = .pi / 4,
        crestHeight: CGFloat = 0,
        crestSharpness: CGFloat = 0
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.steepness = steepness
        self.harmonicOffset = harmonicOffset
        self.crestHeight = crestHeight
        self.crestSharpness = crestSharpness

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
            let envelope = crestHeight * sin(0.5 * pt.angle + phase * 0.3)
            let sharpness = crestSharpness * sin(3 * pt.angle + phase * 1.5)
            let x = pt.x * rect.width
            let y = centerY + amp * (primary + harmonic + envelope + sharpness)

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

// MARK: - Stroke-only Wave Shape

/// Renders only the wave line (no fill), for crest highlight strokes.
struct OceanWaveStrokeShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat
    let steepness: CGFloat
    let harmonicOffset: CGFloat
    let crestHeight: CGFloat
    let crestSharpness: CGFloat

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
        harmonicOffset: CGFloat = .pi / 4,
        crestHeight: CGFloat = 0,
        crestSharpness: CGFloat = 0
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.steepness = steepness
        self.harmonicOffset = harmonicOffset
        self.crestHeight = crestHeight
        self.crestSharpness = crestSharpness

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
            let envelope = crestHeight * sin(0.5 * pt.angle + phase * 0.3)
            let sharpness = crestSharpness * sin(3 * pt.angle + phase * 1.5)
            let x = pt.x * rect.width
            let y = centerY + amp * (primary + harmonic + envelope + sharpness)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

// MARK: - Foam Gradient Shape

/// Thin gradient band at wave crests: white fading downward.
/// Uses the same wave formula to align with the wave top.
struct OceanFoamGradientShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat
    let steepness: CGFloat
    let harmonicOffset: CGFloat
    let crestHeight: CGFloat
    let crestSharpness: CGFloat
    /// Height of foam band as fraction of rect height.
    let foamDepth: CGFloat

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
        harmonicOffset: CGFloat = .pi / 4,
        crestHeight: CGFloat = 0,
        crestSharpness: CGFloat = 0,
        foamDepth: CGFloat = 0.03
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.steepness = steepness
        self.harmonicOffset = harmonicOffset
        self.crestHeight = crestHeight
        self.crestSharpness = crestSharpness
        self.foamDepth = foamDepth

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
        let foamH = rect.height * foamDepth

        var topPoints: [CGPoint] = []
        topPoints.reserveCapacity(points.count)

        for pt in points {
            let primary = sin(pt.angle + phase)
            let harmonic = steepness * sin(2 * pt.angle + phase + harmonicOffset)
            let envelope = crestHeight * sin(0.5 * pt.angle + phase * 0.3)
            let sharpness = crestSharpness * sin(3 * pt.angle + phase * 1.5)
            let x = pt.x * rect.width
            let y = centerY + amp * (primary + harmonic + envelope + sharpness)
            topPoints.append(CGPoint(x: x, y: y))
        }

        var path = Path()
        // Top edge (wave line)
        for (i, point) in topPoints.enumerated() {
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        // Bottom edge (shifted down by foamDepth)
        for point in topPoints.reversed() {
            path.addLine(to: CGPoint(x: point.x, y: point.y + foamH))
        }
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
    var crestHeight: CGFloat = 0
    var crestSharpness: CGFloat = 0
    /// Duration of one full phase cycle (seconds). Slower = more distant wave.
    var driftDuration: TimeInterval = 6
    /// Drift direction. Reverse creates cross-current depth effect.
    var reverseDirection: Bool = false
    /// White stroke along wave crest line.
    var strokeColor: Color? = nil
    var strokeWidth: CGFloat = 1
    var strokeOpacity: Double = 0.3
    /// Foam gradient band below crest.
    var foamColor: Color? = nil
    var foamOpacity: Double = 0.25
    var foamDepth: CGFloat = 0.03

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Fill layer
            OceanWaveShape(
                amplitude: amplitude,
                frequency: frequency,
                phase: phase,
                verticalOffset: verticalOffset,
                steepness: steepness,
                harmonicOffset: harmonicOffset,
                crestHeight: crestHeight,
                crestSharpness: crestSharpness
            )
            .fill(color.opacity(opacity))

            // Foam gradient layer
            if let foamColor {
                OceanFoamGradientShape(
                    amplitude: amplitude,
                    frequency: frequency,
                    phase: phase,
                    verticalOffset: verticalOffset,
                    steepness: steepness,
                    harmonicOffset: harmonicOffset,
                    crestHeight: crestHeight,
                    crestSharpness: crestSharpness,
                    foamDepth: foamDepth
                )
                .fill(
                    LinearGradient(
                        colors: [foamColor.opacity(foamOpacity), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Stroke layer
            if let strokeColor {
                OceanWaveStrokeShape(
                    amplitude: amplitude,
                    frequency: frequency,
                    phase: phase,
                    verticalOffset: verticalOffset,
                    steepness: steepness,
                    harmonicOffset: harmonicOffset,
                    crestHeight: crestHeight,
                    crestSharpness: crestSharpness
                )
                .stroke(strokeColor.opacity(strokeOpacity), lineWidth: strokeWidth)
            }
        }
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
        .onAppear {
            guard !reduceMotion else { return }
            let target: CGFloat = reverseDirection ? -(2 * .pi) : (2 * .pi)
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = target
            }
        }
    }
}
