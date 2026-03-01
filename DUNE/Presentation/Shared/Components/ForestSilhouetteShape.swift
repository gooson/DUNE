import SwiftUI

/// Mountain/forest silhouette Shape for the Forest Green theme.
///
/// Generates a ridge-line profile using:
/// - Base sine wave for primary mountain contour
/// - 3rd harmonic for rugged peaks
/// - Triangle pulse for occasional tree-top silhouettes
/// - Pre-computed edge noise for ukiyo-e washi (和紙) edge texture
///
/// Pre-computes all sample points at init; `path(in:)` only scales —
/// no heavy parsing per render.
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

    private let points: [(x: CGFloat, angle: CGFloat)]
    private let edgeNoise: [CGFloat]
    private static let sampleCount = 120

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

        let count = Self.sampleCount
        var pts: [(x: CGFloat, angle: CGFloat)] = []
        pts.reserveCapacity(count + 1)
        for i in 0...count {
            let x = CGFloat(i) / CGFloat(count)
            let angle = x * frequency * 2 * .pi
            pts.append((x: x, angle: angle))
        }
        self.points = pts

        // Deterministic pseudo-random edge noise for washi edge effect.
        // Uses product of two incommensurate sines — repeatable across launches.
        var noise: [CGFloat] = []
        noise.reserveCapacity(count + 1)
        for i in 0...count {
            let d = Double(i)
            let n = sin(d * 7.3 + 2.1) * sin(d * 13.7 + 5.3)
            noise.append(CGFloat(n))
        }
        self.edgeNoise = noise
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset
        let edgeScale: CGFloat = 2.0 // max ±2pt edge roughness

        var path = Path()
        for (i, pt) in points.enumerated() {
            let x = pt.x * rect.width
            let angle = pt.angle + phase

            // Base ridge contour
            var y = sin(angle)

            // 3rd harmonic for rugged peaks
            y += ruggedness * 0.4 * sin(3 * angle + 1.2)

            // Triangle pulse for tree-top silhouettes
            if treeDensity > 0 {
                let treePulse = Self.trianglePulse(angle: angle, sharpness: 8.0)
                y += treeDensity * 0.3 * treePulse
            }

            let yPos = centerY + amp * y + edgeNoise[i] * edgeScale

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
    private static func trianglePulse(angle: CGFloat, sharpness: CGFloat) -> CGFloat {
        // Modulo 2π, then create a sharp triangle centered around π
        let wrapped = angle.truncatingRemainder(dividingBy: 2 * .pi)
        let normalized = abs(wrapped - .pi) / .pi  // 0 at π, 1 at 0/2π
        let pulse = Swift.max(0, 1.0 - normalized * sharpness)
        return -pulse  // Negative = upward (toward top of screen)
    }
}

// MARK: - Forest Wave Overlay View

/// Single animated forest silhouette layer with bokashi gradient and optional grain.
struct ForestWaveOverlayView: View {
    let color: Color
    let opacity: Double
    let amplitude: CGFloat
    let frequency: CGFloat
    let verticalOffset: CGFloat
    let bottomFade: CGFloat
    let ruggedness: CGFloat
    let treeDensity: CGFloat
    let driftDuration: Double
    let showGrain: Bool

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        color: Color,
        opacity: Double = 0.10,
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 1.5,
        verticalOffset: CGFloat = 0.5,
        bottomFade: CGFloat = 0.4,
        ruggedness: CGFloat = 0.3,
        treeDensity: CGFloat = 0,
        driftDuration: Double = 8,
        showGrain: Bool = false
    ) {
        self.color = color
        self.opacity = opacity
        self.amplitude = amplitude
        self.frequency = frequency
        self.verticalOffset = verticalOffset
        self.bottomFade = bottomFade
        self.ruggedness = ruggedness
        self.treeDensity = treeDensity
        self.driftDuration = driftDuration
        self.showGrain = showGrain
    }

    var body: some View {
        ZStack {
            ForestSilhouetteShape(
                amplitude: amplitude,
                frequency: frequency,
                phase: phase,
                verticalOffset: verticalOffset,
                ruggedness: ruggedness,
                treeDensity: treeDensity
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

            if showGrain {
                UkiyoeGrainView(opacity: 0.04)
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }
}

// MARK: - Ukiyo-e Grain Overlay

/// Procedural wood-grain noise overlay rendered via Canvas.
/// Simulates ukiyo-e woodblock print texture.
/// Rendered once at init, no per-frame computation.
struct UkiyoeGrainView: View {
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            // Deterministic pseudo-random noise grid
            let step: CGFloat = 3
            let cols = Int(size.width / step)
            let rows = Int(size.height / step)

            for row in 0..<rows {
                for col in 0..<cols {
                    // Two incommensurate sine products for pseudo-random noise
                    let seed = Double(row * 997 + col * 131)
                    let noise = sin(seed * 0.1) * sin(seed * 0.073) * sin(seed * 0.031)
                    let alpha = abs(noise) * 0.15 // very subtle

                    let rect = CGRect(
                        x: CGFloat(col) * step,
                        y: CGFloat(row) * step,
                        width: step,
                        height: step
                    )
                    context.fill(
                        Path(rect),
                        with: .color(.black.opacity(alpha))
                    )
                }
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .drawingGroup() // Flatten to single texture for GPU performance
    }
}
