import SwiftUI

// MARK: - Hanok Wave Overlay View

/// Single animated dalhangari wave layer with gradient fade,
/// ink-wash crest highlight, and wind-sway breath modulation.
struct HanokWaveOverlayView: View {
    var color: Color
    var opacity: Double = 0.10
    var amplitude: CGFloat = 0.05
    var frequency: CGFloat = 1.5
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0.4
    var asymmetry: CGFloat = 0.3
    var organicBlend: CGFloat = 0.15
    var driftDuration: Double = 8
    var crestColor: Color? = nil
    var crestOpacity: Double = 0.18
    var crestWidth: CGFloat = 1.2
    /// Wind-sway breath intensity (0 = none, 0.15 = strong).
    /// Modulates amplitude as a function of phase for organic wind feel.
    var breathIntensity: CGFloat = 0

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 6 turns ensures all sub-harmonic phase dependencies (lowest: phase/3)
    /// complete full cycles for seamless looping.
    private static let phaseLoopTurns: CGFloat = 6
    private var phaseTarget: CGFloat { 2 * .pi * Self.phaseLoopTurns }
    private var phaseDuration: Double { driftDuration * Double(Self.phaseLoopTurns) }

    /// Current amplitude with breath modulation derived from drift phase.
    /// Uses an irrational-ratio multiplier (0.13) to avoid periodic alignment
    /// with the base wave, producing organic variation without a separate @State.
    private var modulatedAmplitude: CGFloat {
        guard breathIntensity > 0 else { return amplitude }
        return amplitude * (1 + breathIntensity * sin(phase * 0.13))
    }

    /// Shared shape instance for fill and crest strokes.
    private var dalhangariShape: DalhangariWaveShape {
        DalhangariWaveShape(
            amplitude: modulatedAmplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset,
            asymmetry: asymmetry,
            organicBlend: organicBlend
        )
    }

    private struct AnimationKey: Hashable {
        let driftDuration: Double
        let reduceMotion: Bool
    }

    private func restartAnimations() {
        phase = 0

        guard !reduceMotion, driftDuration > 0 else { return }

        withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
            phase = phaseTarget
        }
    }

    var body: some View {
        let shape = dalhangariShape
        ZStack {
            shape
                .fill(color.opacity(opacity))
                .bottomFadeMask(bottomFade)

            if let crestColor {
                ZStack {
                    // Wide translucent crest band (ink wash blur).
                    shape
                        .stroke(
                            crestColor.opacity(crestOpacity * 0.48),
                            style: StrokeStyle(lineWidth: crestWidth * 2.6, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 1.1)

                    // Core crest highlight line.
                    shape
                        .stroke(
                            crestColor.opacity(crestOpacity),
                            style: StrokeStyle(lineWidth: crestWidth, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 0.25)
                }
                .drawingGroup()
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.87)
                    )
                )
                .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
        .task(id: AnimationKey(driftDuration: driftDuration, reduceMotion: reduceMotion)) {
            restartAnimations()
        }
    }
}

// MARK: - Hanok Tab Background

/// Multi-layer parallax dalhangari wave background for tab root screens.
///
/// Three layers of asymmetric organic curves creating ink-wash depth:
/// 1. **Far** — distant mist, lightest, very slow drift
/// 2. **Mid** — signature dalhangari curve, medium density
/// 3. **Near** — foreground depth, ink-wash crest highlight
///
/// No decorative overlays — negative space (여백의 미).
struct HanokTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    /// Dark mode needs a small visibility lift.
    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.3 : 1.0
    }

    /// Scale factor based on tab preset character.
    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2
        case .today:    1.0
        case .wellness: 0.8
        case .life:     0.6
        }
    }

    var body: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * visibilityBoost

        ZStack(alignment: .top) {
            // Layer 1: Far — ink-wash distant mist (수묵 원경)
            HanokWaveOverlayView(
                color: theme.hanokMistColor,
                opacity: 0.08 * opacityScale,
                amplitude: 0.04 * scale,
                frequency: 0.7,
                verticalOffset: 0.40,
                bottomFade: 0.5,
                asymmetry: 0.2,
                organicBlend: 0.10,
                driftDuration: 28,
                breathIntensity: 0.04
            )
            .frame(height: 160)

            // Layer 2: Mid — signature dalhangari curve (달항아리 곡선)
            HanokWaveOverlayView(
                color: theme.hanokMidColor,
                opacity: 0.18 * opacityScale,
                amplitude: 0.055 * scale,
                frequency: 1.2,
                verticalOffset: 0.55,
                bottomFade: 0.4,
                asymmetry: 0.35,
                organicBlend: 0.18,
                driftDuration: 22,
                breathIntensity: 0.07
            )
            .frame(height: 170)

            // Layer 3: Near — foreground depth with ink-wash crest (수묵 번짐)
            HanokWaveOverlayView(
                color: theme.hanokDeepColor,
                opacity: 0.45 * opacityScale,
                amplitude: 0.048 * scale,
                frequency: 1.8,
                verticalOffset: 0.60,
                bottomFade: 0.4,
                asymmetry: 0.25,
                organicBlend: 0.12,
                driftDuration: 18,
                crestColor: theme.sandColor,
                crestOpacity: 0.36 * opacityScale,
                crestWidth: 1.12,
                breathIntensity: 0.10
            )
            .frame(height: 180)

            // Background gradient
            LinearGradient(
                colors: hanokGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        theme.hanokMistColor.opacity(0.18),
                        theme.hanokMidColor.opacity(0.08),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: DS.Gradient.tabBackgroundEnd
                )
            }
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }

    private var hanokGradientColors: [Color] {
        if isWeatherActive {
            if colorScheme == .dark {
                return [
                    atmosphere.waveColor(for: theme).opacity(DS.Opacity.strong),
                    theme.sandColor.opacity(DS.Opacity.light),
                    theme.hanokMistColor.opacity(DS.Opacity.medium),
                    .clear
                ]
            }
            return atmosphere.gradientColors(for: theme)
        }
        if colorScheme == .dark {
            return [
                theme.sandColor.opacity(DS.Opacity.light),
                theme.hanokMistColor.opacity(DS.Opacity.medium),
                theme.hanokMidColor.opacity(DS.Opacity.light),
                theme.hanokDeepColor.opacity(DS.Opacity.subtle),
                .clear
            ]
        }
        return [
            theme.sandColor.opacity(DS.Opacity.light),
            theme.hanokMistColor.opacity(DS.Opacity.medium),
            theme.hanokMidColor.opacity(DS.Opacity.medium),
            theme.hanokDeepColor.opacity(DS.Opacity.subtle),
            .clear
        ]
    }
}

// MARK: - Hanok Detail Background

/// Subtler 2-layer dalhangari wave for push-destination detail screens.
/// Opacity scaled to ~60% of tab background.
struct HanokDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.25 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Far mist
            HanokWaveOverlayView(
                color: theme.hanokMistColor,
                opacity: 0.05 * visibilityBoost,
                amplitude: 0.035,
                frequency: 0.8,
                verticalOffset: 0.42,
                bottomFade: 0.5,
                asymmetry: 0.2,
                organicBlend: 0.10,
                driftDuration: 26,
                breathIntensity: 0.04
            )
            .frame(height: 150)

            // Near depth
            HanokWaveOverlayView(
                color: theme.hanokDeepColor,
                opacity: 0.27 * visibilityBoost,
                amplitude: 0.04,
                frequency: 1.5,
                verticalOffset: 0.58,
                bottomFade: 0.45,
                asymmetry: 0.25,
                organicBlend: 0.12,
                driftDuration: 20,
                crestColor: theme.sandColor,
                crestOpacity: 0.16 * visibilityBoost,
                crestWidth: 1.0,
                breathIntensity: 0.06
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    theme.sandColor.opacity(DS.Opacity.light),
                    (colorScheme == .dark ? theme.hanokMistColor : theme.hanokMidColor).opacity(DS.Opacity.light),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Hanok Sheet Background

/// Lightest single-layer dalhangari wave for sheet/modal presentations.
/// Opacity scaled to ~40% of tab background.
struct HanokSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.2 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            HanokWaveOverlayView(
                color: theme.hanokMidColor,
                opacity: 0.04 * visibilityBoost,
                amplitude: 0.025,
                frequency: 0.6,
                verticalOffset: 0.40,
                bottomFade: 0.5,
                asymmetry: 0.2,
                organicBlend: 0.10,
                driftDuration: 24,
                crestColor: theme.sandColor,
                crestOpacity: 0.10 * visibilityBoost,
                crestWidth: 0.9,
                breathIntensity: 0.03
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    .clear,
                    theme.sandColor.opacity(DS.Opacity.subtle),
                    (colorScheme == .dark ? theme.hanokMistColor : theme.hanokMidColor).opacity(DS.Opacity.light)
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("HanokTabWaveBackground") {
    HanokTabWaveBackground()
        .environment(\.appTheme, .hanok)
}

#Preview("Hanok Tab — All Presets") {
    TabView {
        ForEach(
            [
                ("Today", WavePreset.today),
                ("Train", WavePreset.train),
                ("Wellness", WavePreset.wellness),
                ("Life", WavePreset.life),
            ],
            id: \.0
        ) { name, preset in
            HanokTabWaveBackground()
                .environment(\.wavePreset, preset)
                .environment(\.appTheme, .hanok)
                .overlay(alignment: .center) {
                    Text(name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .tabItem { Text(name) }
        }
    }
}

#Preview("Hanok Tab — Dark") {
    HanokTabWaveBackground()
        .environment(\.appTheme, .hanok)
        .preferredColorScheme(.dark)
}
