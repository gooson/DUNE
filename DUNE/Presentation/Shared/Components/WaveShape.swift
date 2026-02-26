import SwiftUI

/// Sine-wave Shape for brand motif (aligns with app icon's HRV waveform).
///
/// Pre-computes normalised angles at init; `path(in:)` only evaluates
/// `sin(angle + phase)` and scales to rect — no heavy parsing per render
/// (Correction #82).
struct WaveShape: Shape {
    /// Wave height as a fraction of the rect height (0…1).
    let amplitude: CGFloat
    /// Number of full sine periods across the rect width.
    let frequency: CGFloat
    /// Phase offset in radians (0…2π). Animatable for drift effect.
    var phase: CGFloat
    /// Vertical center of the wave as a fraction of the rect height (0…1).
    let verticalOffset: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    /// Pre-computed normalised x positions and their corresponding angles.
    private let points: [(x: CGFloat, angle: CGFloat)]
    private static let sampleCount = 120

    init(
        amplitude: CGFloat = 0.03,
        frequency: CGFloat = 2,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.7
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset

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
            let x = pt.x * rect.width
            let y = centerY + amp * sin(pt.angle + phase)

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

// MARK: - Convenience overlay

/// Subtle animated wave background decoration.
struct WaveOverlayView: View {
    var color: Color = DS.Color.warmGlow
    var opacity: Double = 0.04
    var amplitude: CGFloat = 0.03
    var frequency: CGFloat = 2
    var verticalOffset: CGFloat = 0.7
    /// Smooth fade-out at the bottom edge (0 = no fade, 1 = full fade).
    var bottomFade: CGFloat = 0

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WaveShape(
            amplitude: amplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset
        )
        .fill(color.opacity(opacity))
        .mask {
            if bottomFade > 0 {
                // Opaque top → fade only at the bottom portion
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
            withAnimation(DS.Animation.waveDrift) {
                phase = 2 * .pi
            }
        }
    }
}

// MARK: - Tab Background

/// Common tab background pattern: wave motif + warm gradient.
/// Each tab provides its own `primaryColor` (key color for that tab).
struct TabWaveBackground: View {
    let primaryColor: Color

    var body: some View {
        ZStack(alignment: .top) {
            WaveOverlayView(
                color: primaryColor,
                opacity: 0.15,
                amplitude: 0.06,
                frequency: DS.Gradient.waveFrequency,
                verticalOffset: 0.5,
                bottomFade: 0.4
            )
            .frame(height: 200)

            LinearGradient(
                colors: [primaryColor.opacity(DS.Opacity.medium), DS.Color.warmGlow.opacity(DS.Opacity.subtle), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}
