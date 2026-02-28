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

/// Tab root background: wave motif + warm gradient.
/// Reads `wavePreset`, `waveColor`, and `weatherAtmosphere` from the environment.
/// When preset is `.today` and a non-default atmosphere is set, wave color/params
/// adapt to current weather conditions.
struct TabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color
    @Environment(\.weatherAtmosphere) private var atmosphere

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    private var resolvedColor: Color {
        isWeatherActive ? atmosphere.waveColor : color
    }

    private var resolvedAmplitude: CGFloat {
        isWeatherActive ? atmosphere.waveAmplitude : preset.amplitude
    }

    private var resolvedFrequency: CGFloat {
        isWeatherActive ? atmosphere.waveFrequency : preset.frequency
    }

    private var resolvedOpacity: Double {
        isWeatherActive ? atmosphere.waveOpacity : preset.opacity
    }

    var body: some View {
        let gradientColors = isWeatherActive
            ? atmosphere.gradientColors
            : [color.opacity(DS.Opacity.medium), DS.Color.warmGlow.opacity(DS.Opacity.subtle), .clear]

        ZStack(alignment: .top) {
            // Primary wave
            WaveOverlayView(
                color: resolvedColor,
                opacity: resolvedOpacity,
                amplitude: resolvedAmplitude,
                frequency: resolvedFrequency,
                verticalOffset: preset.verticalOffset,
                bottomFade: preset.bottomFade
            )
            .frame(height: 200)

            // Secondary wave (Train tab dual-layer)
            if let secondary = preset.secondaryWave {
                WaveOverlayView(
                    color: color,
                    opacity: secondary.opacity,
                    amplitude: secondary.amplitude,
                    frequency: secondary.frequency,
                    verticalOffset: preset.verticalOffset,
                    bottomFade: preset.bottomFade
                )
                .frame(height: 200)
            }

            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }
}

// MARK: - Detail Background

/// Subtler wave for push-destination detail screens.
/// Inherits `wavePreset` / `waveColor` from parent tab, scaled down (50% amp, 70% opacity).
struct DetailWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color

    var body: some View {
        let gradientTop = color.opacity(DS.Opacity.light)

        ZStack(alignment: .top) {
            WaveOverlayView(
                color: color,
                opacity: preset.opacity * 0.7,
                amplitude: preset.amplitude * 0.5,
                frequency: preset.frequency,
                verticalOffset: preset.verticalOffset,
                bottomFade: 0.5
            )
            .frame(height: 150)

            LinearGradient(
                colors: [gradientTop, .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sheet Background

/// Lightest wave for sheet / modal presentations.
/// Scaled down further (40% amp, 60% opacity) with shorter height.
struct SheetWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color

    var body: some View {
        let gradientTop = color.opacity(DS.Opacity.light)

        ZStack(alignment: .top) {
            WaveOverlayView(
                color: color,
                opacity: preset.opacity * 0.6,
                amplitude: preset.amplitude * 0.4,
                frequency: preset.frequency,
                verticalOffset: 0.5,
                bottomFade: 0.5
            )
            .frame(height: 120)

            LinearGradient(
                colors: [gradientTop, .clear],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}
