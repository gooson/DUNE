import SwiftUI

// MARK: - Shared Coordinate Helper

@inline(__always)
private func bigWavePt(
    _ nx: CGFloat, _ ny: CGFloat,
    _ w: CGFloat, _ h: CGFloat, _ sway: CGFloat
) -> CGPoint {
    CGPoint(x: nx * w + sway, y: ny * h)
}

// MARK: - Big Wave Body

/// Stylized Japanese-style curling wave for dramatic background decoration.
///
/// Draws a single large wave rising from the base with a characteristic
/// curl at the crest. Uses cubic Bezier curves for natural-looking contours.
/// The `phase` parameter animates a gentle horizontal sway.
struct OceanBigWaveShape: Shape {
    var phase: CGFloat
    let mirror: Bool

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    init(phase: CGFloat = 0, mirror: Bool = false) {
        self.phase = phase
        self.mirror = mirror
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let w = rect.width
        let h = rect.height
        let sway = sin(phase) * w * 0.01

        var path = Path()

        // Start at bottom-left
        path.move(to: bigWavePt(0.0, 1.0, w, h, sway))

        // 1. Smooth rise from base to peak
        path.addCurve(
            to: bigWavePt(0.35, 0.04, w, h, sway),
            control1: bigWavePt(0.08, 0.70, w, h, sway),
            control2: bigWavePt(0.28, 0.06, w, h, sway)
        )

        // 2. Lip curling forward and down
        path.addCurve(
            to: bigWavePt(0.58, 0.28, w, h, sway),
            control1: bigWavePt(0.42, 0.0, w, h, sway),
            control2: bigWavePt(0.56, 0.10, w, h, sway)
        )

        // 3. Concave face descending to base
        path.addCurve(
            to: bigWavePt(0.38, 1.0, w, h, sway),
            control1: bigWavePt(0.55, 0.52, w, h, sway),
            control2: bigWavePt(0.42, 0.82, w, h, sway)
        )

        // Close along bottom
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        if mirror {
            return path.applying(
                CGAffineTransform(translationX: w, y: 0).scaledBy(x: -1, y: 1)
            )
        }

        return path
    }
}

// MARK: - Big Wave Crest (Foam Stroke)

/// Traces the crest/curl line of the big wave for white foam stroke.
/// Open path (not closed) — intended for `.stroke()`.
struct OceanBigWaveCrestShape: Shape {
    var phase: CGFloat
    let mirror: Bool

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    init(phase: CGFloat = 0, mirror: Bool = false) {
        self.phase = phase
        self.mirror = mirror
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let w = rect.width
        let h = rect.height
        let sway = sin(phase) * w * 0.01

        var path = Path()

        // Start partway up the rise
        path.move(to: bigWavePt(0.25, 0.18, w, h, sway))

        // Rise to peak
        path.addCurve(
            to: bigWavePt(0.35, 0.04, w, h, sway),
            control1: bigWavePt(0.28, 0.10, w, h, sway),
            control2: bigWavePt(0.32, 0.05, w, h, sway)
        )

        // Lip curling forward and down
        path.addCurve(
            to: bigWavePt(0.58, 0.28, w, h, sway),
            control1: bigWavePt(0.42, 0.0, w, h, sway),
            control2: bigWavePt(0.56, 0.10, w, h, sway)
        )

        if mirror {
            return path.applying(
                CGAffineTransform(translationX: w, y: 0).scaledBy(x: -1, y: 1)
            )
        }

        return path
    }
}

// MARK: - Animated Overlay

/// Animated big wave overlay with gentle sway and foam crest.
struct OceanBigWaveOverlayView: View {
    var color: Color
    var foamColor: Color
    var opacity: Double = 0.12
    var foamOpacity: Double = 0.3
    var foamWidth: CGFloat = 2.0
    var mirror: Bool = false
    /// Duration of one full sway cycle (seconds).
    var swayDuration: TimeInterval = 12

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            OceanBigWaveShape(phase: phase, mirror: mirror)
                .fill(fillColor)

            OceanBigWaveCrestShape(phase: phase, mirror: mirror)
                .stroke(crestColor, lineWidth: foamWidth)
        }
        .clipped()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion, swayDuration > 0 else { return }
            withAnimation(.linear(duration: swayDuration).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }

    private var fillColor: Color { color.opacity(opacity) }
    private var crestColor: Color { foamColor.opacity(foamOpacity) }
}
