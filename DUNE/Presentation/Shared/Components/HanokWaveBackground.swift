import SwiftUI
import UIKit

// MARK: - Hanok Wave Overlay View

/// Single animated hanok eave layer with gradient fade and optional hanji texture.
struct HanokWaveOverlayView: View {
    var color: Color
    var opacity: Double = 0.10
    var amplitude: CGFloat = 0.05
    var frequency: CGFloat = 1.5
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0.4
    var uplift: CGFloat = 0.2
    var tileRipple: CGFloat = 0
    var tileFrequency: CGFloat = 8.0
    var driftDuration: Double = 8
    var showHanji: Bool = false
    var hanjiOpacity: Double = 0.03
    var crestColor: Color? = nil
    var crestOpacity: Double = 0.18
    var crestWidth: CGFloat = 1.2

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Harmonic multipliers (uplift uses 2nd harmonic + 0.5 swell) need
    /// LCM = 10 turns for seamless loop.
    private static let phaseLoopTurns: CGFloat = 10
    private var phaseTarget: CGFloat { 2 * .pi * Self.phaseLoopTurns }
    private var phaseDuration: Double { driftDuration * Double(Self.phaseLoopTurns) }

    /// Shared shape instance for fill and crest strokes.
    private var eaveShape: HanokEaveShape {
        HanokEaveShape(
            amplitude: amplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset,
            uplift: uplift,
            tileRipple: tileRipple,
            tileFrequency: tileFrequency
        )
    }

    var body: some View {
        ZStack {
            eaveShape
                .fill(color.opacity(opacity))
                .bottomFadeMask(bottomFade)

            if let crestColor {
                ZStack {
                    // Wide translucent crest band.
                    eaveShape
                        .stroke(
                            crestColor.opacity(crestOpacity * 0.48),
                            style: StrokeStyle(lineWidth: crestWidth * 2.6, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 1.1)

                    // Core crest highlight line.
                    eaveShape
                        .stroke(
                            crestColor.opacity(crestOpacity),
                            style: StrokeStyle(lineWidth: crestWidth, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 0.25)
                }
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.87)
                    )
                )
                .blendMode(.screen)
            }

            if showHanji {
                HanjiTextureView(opacity: hanjiOpacity)
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion, driftDuration > 0 else { return }
            withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
                phase = phaseTarget
            }
        }
        .onAppear {
            guard !reduceMotion, driftDuration > 0 else { return }
            Task { @MainActor in
                phase = 0
                withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
                    phase = phaseTarget
                }
            }
        }
    }
}

// MARK: - Hanji Texture Overlay

/// Procedural hanji (한지) paper fiber texture pre-rendered to a UIImage.
/// Simulates the subtle fiber patterns of traditional Korean paper.
/// Rendered once as a static constant — zero per-frame computation.
private struct HanjiTextureView: View {
    let opacity: Double

    /// Pre-rendered hanji texture. Computed once at first access.
    /// Uses layered sine products to simulate paper fiber directionality.
    private static let hanjiImage: UIImage = {
        let size = CGSize(width: 400, height: 200)
        let step: CGFloat = 3
        let cols = Int(size.width / step)
        let rows = Int(size.height / step)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            for row in 0..<rows {
                for col in 0..<cols {
                    let seed = Double(row * 853 + col * 149)
                    // Directional fiber pattern — horizontal bias for hanji
                    let horizontal = sin(seed * 0.09) * sin(seed * 0.061)
                    let vertical = sin(seed * 0.043) * sin(seed * 0.029) * 0.4
                    let noise = horizontal + vertical
                    let alpha = abs(noise) * 0.10
                    // Warm-tinted fiber (subtle cream tone)
                    cgContext.setFillColor(
                        UIColor(red: 0.95, green: 0.90, blue: 0.82, alpha: alpha).cgColor
                    )
                    cgContext.fill(CGRect(
                        x: CGFloat(col) * step,
                        y: CGFloat(row) * step,
                        width: step,
                        height: step
                    ))
                }
            }
        }
    }()

    var body: some View {
        Image(uiImage: Self.hanjiImage)
            .resizable()
            .interpolation(.none)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

// MARK: - Hanok Tab Background

/// Multi-layer parallax hanok rooftop background for tab root screens.
///
/// Layers (back to front):
/// 1. **Far** — distant giwa rooftops (기와), lightest, slow drift
/// 2. **Mid** — cheoma eave curves (처마), moderate density
/// 3. **Near** — foreground eave with tile texture, darkest
///
/// Includes hanji paper texture overlay on near layer.
struct HanokTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    /// Dark mode needs a small visibility lift for warm tones.
    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.3 : 1.0
    }

    /// Scale factor based on tab preset character.
    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2   // Active courtyard
        case .today:    1.0
        case .wellness: 0.8   // Tranquil garden
        case .life:     0.6   // Distant village
        }
    }

    var body: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * visibilityBoost

        ZStack(alignment: .top) {
            // Layer 1: Far — distant giwa rooftops
            HanokWaveOverlayView(
                color: theme.hanokMistColor,
                opacity: 0.09 * opacityScale,
                amplitude: 0.04 * scale,
                frequency: 0.8,
                verticalOffset: 0.40,
                bottomFade: 0.5,
                uplift: 0.15,
                driftDuration: 25,
                crestColor: theme.hanokMistColor,
                crestOpacity: 0.10 * opacityScale,
                crestWidth: 0.9
            )
            .frame(height: 160)

            // Layer 2: Mid — cheoma eave curves
            HanokWaveOverlayView(
                color: theme.hanokMidColor,
                opacity: 0.22 * opacityScale,
                amplitude: 0.06 * scale,
                frequency: 1.4,
                verticalOffset: 0.55,
                bottomFade: 0.4,
                uplift: 0.25,
                tileRipple: 0.05,
                driftDuration: 20,
                crestColor: theme.hanokMistColor,
                crestOpacity: 0.12 * opacityScale,
                crestWidth: 1.0
            )
            .frame(height: 170)

            // Layer 3: Near — foreground eave with tile texture
            HanokWaveOverlayView(
                color: theme.hanokDeepColor,
                opacity: 0.65 * opacityScale,
                amplitude: 0.05 * scale,
                frequency: 2.0,
                verticalOffset: 0.60,
                bottomFade: 0.4,
                uplift: 0.30,
                tileRipple: 0.10,
                tileFrequency: 10.0,
                driftDuration: 16,
                showHanji: true,
                hanjiOpacity: colorScheme == .dark ? 0.012 : 0.025,
                crestColor: theme.hanokMidColor,
                crestOpacity: 0.45 * opacityScale,
                crestWidth: 1.1
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
                    theme.hanokMistColor.opacity(DS.Opacity.medium),
                    .clear
                ]
            }
            return atmosphere.gradientColors(for: theme)
        }
        if colorScheme == .dark {
            return [
                theme.hanokMistColor.opacity(DS.Opacity.medium),
                theme.hanokMidColor.opacity(DS.Opacity.light),
                theme.hanokDeepColor.opacity(DS.Opacity.subtle),
                .clear
            ]
        }
        return [
            theme.hanokMidColor.opacity(DS.Opacity.medium),
            theme.hanokDeepColor.opacity(DS.Opacity.subtle),
            .clear
        ]
    }
}

// MARK: - Hanok Detail Background

/// Subtler 2-layer hanok eave for push-destination detail screens.
/// Positioned at the bottom of the screen.
struct HanokDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.25 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Far — distant rooftops
            HanokWaveOverlayView(
                color: theme.hanokMistColor,
                opacity: 0.07 * visibilityBoost,
                amplitude: 0.035,
                frequency: 1.2,
                verticalOffset: 0.42,
                bottomFade: 0.5,
                uplift: 0.18,
                driftDuration: 22,
                crestColor: theme.hanokMistColor,
                crestOpacity: 0.09 * visibilityBoost,
                crestWidth: 0.9
            )
            .frame(height: 150)

            // Near — closer eave
            HanokWaveOverlayView(
                color: theme.hanokDeepColor,
                opacity: 0.45 * visibilityBoost,
                amplitude: 0.045,
                frequency: 1.8,
                verticalOffset: 0.58,
                bottomFade: 0.45,
                uplift: 0.22,
                tileRipple: 0.06,
                driftDuration: 18,
                crestColor: theme.hanokMistColor,
                crestOpacity: 0.12 * visibilityBoost,
                crestWidth: 1.0
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
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

/// Lightest single-layer hanok eave for sheet/modal presentations.
/// Minimal tile detail, positioned at the bottom.
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
                opacity: 0.09 * visibilityBoost,
                amplitude: 0.03,
                frequency: 0.7,
                verticalOffset: 0.40,
                bottomFade: 0.5,
                uplift: 0.15,
                driftDuration: 20,
                crestColor: theme.hanokMistColor,
                crestOpacity: 0.10 * visibilityBoost,
                crestWidth: 1.0
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    .clear,
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
