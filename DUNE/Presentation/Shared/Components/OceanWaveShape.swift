import SwiftUI

// MARK: - Shared Wave Computation

/// Pre-computed sample points for wave rendering.
/// Shared across all wave shape variants to avoid duplication.
private struct WaveSamples {
    let points: [(x: CGFloat, angle: CGFloat)]
    static let sampleCount = 120

    init(frequency: CGFloat) {
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
}

/// Phase-scaling constants for wave harmonics.
/// - `envelopeDrift`: Slow drift for low-frequency envelope (breaks periodicity)
/// - `sharpnessDrift`: Faster drift for high-frequency crest detail
private enum HarmonicPhase {
    static let envelopeDrift: CGFloat = 0.3
    static let sharpnessDrift: CGFloat = 1.5
}

/// Single wave y-value computation shared by all shape variants.
@inline(__always)
private func waveY(
    angle: CGFloat,
    phase: CGFloat,
    centerY: CGFloat,
    amp: CGFloat,
    steepness: CGFloat,
    harmonicOffset: CGFloat,
    crestHeight: CGFloat,
    crestSharpness: CGFloat
) -> CGFloat {
    let primary = sin(angle + phase)
    let harmonic = steepness * sin(2 * angle + phase + harmonicOffset)
    let envelope = crestHeight * sin(0.5 * angle + phase * HarmonicPhase.envelopeDrift)
    let sharpness = crestSharpness * sin(3 * angle + phase * HarmonicPhase.sharpnessDrift)
    return centerY + amp * (primary + harmonic + envelope + sharpness)
}

// MARK: - Fill Shape

/// Asymmetric ocean-wave Shape with harmonic enrichment.
///
/// Combines a primary sine with higher harmonics to create sharp crests,
/// gentle troughs, and variable wave heights — matching Japanese-style
/// ocean wave silhouettes.
///
/// Pre-computes normalised angles at init; `path(in:)` only evaluates
/// four `sin()` calls per sample point and scales to rect.
struct OceanWaveShape: Shape {
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

    private let samples: WaveSamples

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
        self.crestHeight = Swift.min(crestHeight, 0.4)
        self.crestSharpness = Swift.min(crestSharpness, 0.15)
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var path = Path()
        for (i, pt) in samples.points.enumerated() {
            let x = pt.x * rect.width
            let y = waveY(
                angle: pt.angle, phase: phase,
                centerY: centerY, amp: amp,
                steepness: steepness, harmonicOffset: harmonicOffset,
                crestHeight: crestHeight, crestSharpness: crestSharpness
            )

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

// MARK: - Stroke Shape

/// Renders only the wave line (no fill), for crest highlight strokes.
/// Uses the shared wave formula and sample points.
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

    private let samples: WaveSamples

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
        self.crestHeight = Swift.min(crestHeight, 0.4)
        self.crestSharpness = Swift.min(crestSharpness, 0.15)
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var path = Path()
        for (i, pt) in samples.points.enumerated() {
            let x = pt.x * rect.width
            let y = waveY(
                angle: pt.angle, phase: phase,
                centerY: centerY, amp: amp,
                steepness: steepness, harmonicOffset: harmonicOffset,
                crestHeight: crestHeight, crestSharpness: crestSharpness
            )

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
/// Uses the shared wave formula; no intermediate array allocation.
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

    private let samples: WaveSamples

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
        self.crestHeight = Swift.min(crestHeight, 0.4)
        self.crestSharpness = Swift.min(crestSharpness, 0.15)
        self.foamDepth = foamDepth
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset
        let foamH = rect.height * foamDepth
        let pts = samples.points

        var path = Path()

        // Forward pass: top edge (wave line)
        for (i, pt) in pts.enumerated() {
            let x = pt.x * rect.width
            let y = waveY(
                angle: pt.angle, phase: phase,
                centerY: centerY, amp: amp,
                steepness: steepness, harmonicOffset: harmonicOffset,
                crestHeight: crestHeight, crestSharpness: crestSharpness
            )
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Reverse pass: bottom edge (shifted down by foamDepth)
        for pt in pts.reversed() {
            let x = pt.x * rect.width
            let y = waveY(
                angle: pt.angle, phase: phase,
                centerY: centerY, amp: amp,
                steepness: steepness, harmonicOffset: harmonicOffset,
                crestHeight: crestHeight, crestSharpness: crestSharpness
            ) + foamH
            path.addLine(to: CGPoint(x: x, y: y))
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
    var strokeStyle: WaveStrokeStyle? = nil
    /// Foam gradient band below crest.
    var foamStyle: WaveFoamStyle? = nil

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
            .fill(fillColor)

            // Foam gradient layer
            if let foam = foamStyle {
                OceanFoamGradientShape(
                    amplitude: amplitude,
                    frequency: frequency,
                    phase: phase,
                    verticalOffset: verticalOffset,
                    steepness: steepness,
                    harmonicOffset: harmonicOffset,
                    crestHeight: crestHeight,
                    crestSharpness: crestSharpness,
                    foamDepth: foam.depth
                )
                .fill(foam.gradient)
            }

            // Stroke layer
            if let stroke = strokeStyle {
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
                .stroke(stroke.resolvedColor, lineWidth: stroke.width)
            }
        }
        .clipped()
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
            guard !reduceMotion, driftDuration > 0 else { return }
            let target: CGFloat = reverseDirection ? -(2 * .pi) : (2 * .pi)
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = target
            }
        }
    }

    // Pre-compute fill color to avoid allocation in body during animation
    private var fillColor: Color { color.opacity(opacity) }
}

// MARK: - Style Types

/// Stroke style for wave crest highlight.
struct WaveStrokeStyle: Sendable {
    let color: Color
    let width: CGFloat
    let opacity: Double
    /// Pre-resolved color to avoid per-frame allocation.
    let resolvedColor: Color

    init(color: Color, width: CGFloat, opacity: Double) {
        self.color = color
        self.width = width
        self.opacity = opacity
        self.resolvedColor = color.opacity(opacity)
    }
}

/// Foam gradient style for wave crest band.
struct WaveFoamStyle: Sendable {
    let color: Color
    let opacity: Double
    let depth: CGFloat
    /// Pre-built gradient to avoid per-frame allocation.
    let gradient: LinearGradient

    init(color: Color, opacity: Double, depth: CGFloat) {
        self.color = color
        self.opacity = opacity
        self.depth = depth
        self.gradient = LinearGradient(
            colors: [color.opacity(opacity), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
