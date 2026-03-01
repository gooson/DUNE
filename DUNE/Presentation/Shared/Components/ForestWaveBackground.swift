import SwiftUI
import UIKit

// MARK: - Forest Wave-Specific Colors (File-Private)

/// Forest wave layer colors are only consumed by forest backgrounds.
/// Kept file-private to avoid polluting the shared AppTheme extension.
private extension AppTheme {
    var forestDeepColor: Color { Color("ForestDeep") }
    var forestMidColor: Color { Color("ForestTabLife") }
    var forestMistColor: Color { Color("ForestSand") }
}

// MARK: - Forest Wave Overlay View

/// Single animated forest silhouette layer with bokashi gradient and optional grain.
struct ForestWaveOverlayView: View {
    var color: Color
    var opacity: Double = 0.10
    var amplitude: CGFloat = 0.05
    var frequency: CGFloat = 1.5
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0.4
    var treeDensity: CGFloat = 0.0
    var driftDuration: Double = 8
    var showGrain: Bool = false
    var grainOpacity: Double = 0.04
    var crestColor: Color? = nil
    var crestOpacity: Double = 0.18
    var crestWidth: CGFloat = 1.6

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seamless loop turns. Harmonic multipliers (0.55, 1.3, 1.8, 2.2) require
    /// LCM = 20 turns so every component completes an integer number of cycles.
    private static let phaseLoopTurns: CGFloat = 20
    private var phaseTarget: CGFloat { 2 * .pi * Self.phaseLoopTurns }
    private var phaseDuration: Double { driftDuration * Double(Self.phaseLoopTurns) }

    /// Shared shape instance for fill and crest strokes — avoids 3× identical init.
    private var silhouetteShape: ForestSilhouetteShape {
        ForestSilhouetteShape(
            amplitude: amplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset,
            treeDensity: treeDensity
        )
    }

    var body: some View {
        ZStack {
            silhouetteShape
                .fill(color.opacity(opacity))
                .bottomFadeMask(bottomFade)

            if let crestColor {
                ZStack {
                    // Wide translucent crest band.
                    silhouetteShape
                        .stroke(
                            crestColor.opacity(crestOpacity * 0.48),
                            style: StrokeStyle(lineWidth: crestWidth * 2.6, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 1.2)

                    // Core crest highlight line.
                    silhouetteShape
                        .stroke(
                            crestColor.opacity(crestOpacity),
                            style: StrokeStyle(lineWidth: crestWidth, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 0.3)
                }
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.88)
                    )
                )
                .blendMode(.screen)
            }

            if showGrain {
                UkiyoeGrainView(opacity: grainOpacity)
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion, driftDuration > 0 else { return }
            withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
                phase = phaseTarget
            }
        }
    }
}

// MARK: - Ukiyo-e Grain Overlay

/// Procedural wood-grain noise overlay pre-rendered to a UIImage.
/// Simulates ukiyo-e woodblock print texture.
/// Rendered once as a static constant — zero per-frame computation.
private struct UkiyoeGrainView: View {
    let opacity: Double

    /// Pre-rendered grain texture. Computed once at first access.
    /// Deterministic pseudo-random noise: product of three incommensurate sines.
    private static let grainImage: UIImage = {
        let size = CGSize(width: 400, height: 200)
        let step: CGFloat = 3
        let cols = Int(size.width / step)
        let rows = Int(size.height / step)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            for row in 0..<rows {
                for col in 0..<cols {
                    let seed = Double(row * 997 + col * 131)
                    let noise = sin(seed * 0.1) * sin(seed * 0.073) * sin(seed * 0.031)
                    let alpha = abs(noise) * 0.15
                    cgContext.setFillColor(UIColor.black.withAlphaComponent(alpha).cgColor)
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
        Image(uiImage: Self.grainImage)
            .resizable()
            .interpolation(.none)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

// MARK: - Forest Tab Background

/// Multi-layer parallax forest silhouette background for tab root screens.
///
/// Layers (back to front):
/// 1. **Far** — distant misty treeline, small trees, lightest color
/// 2. **Mid** — middle-distance forest, moderate tree height
/// 3. **Near** — foreground forest with tall conifers, darkest color
///
/// All layers positioned in the lower third of the screen to create
/// a forest-floor perspective looking up at the treeline.
struct ForestTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    /// Dark mode needs a small visibility lift for low-contrast forest tones.
    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.35 : 1.0
    }

    /// Scale factor based on tab preset character.
    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2   // Dense forest
        case .today:    1.0
        case .wellness: 0.8   // Gentle grove
        case .life:     0.6   // Misty meadow
        }
    }

    var body: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * visibilityBoost

        ZStack(alignment: .top) {
            // Layer 1: Far — distant misty treeline (smallest trees, lightest)
            ForestWaveOverlayView(
                color: theme.forestMistColor,
                opacity: 0.09 * opacityScale,
                amplitude: 0.25 * scale,
                frequency: 0.9,
                verticalOffset: 0.58,
                bottomFade: 0.5,
                treeDensity: 0.45,
                driftDuration: 35,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.10 * opacityScale,
                crestWidth: 1
            )
            .frame(height: 150)

            // Layer 2: Mid — middle-distance forest (medium trees)
            ForestWaveOverlayView(
                color: theme.forestMidColor,
                opacity: 0.25 * opacityScale,
                amplitude: 0.35 * scale,
                frequency: 1.65,
                verticalOffset: 0.92,
                bottomFade: 0.4,
                treeDensity: 3.2,
                driftDuration: 27,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.12 * opacityScale,
                crestWidth: 1
            )
            .frame(height: 170)

            // Layer 3: Near — foreground forest with tall conifers (darkest)
            ForestWaveOverlayView(
                color: theme.forestDeepColor,
                opacity: 0.75 * opacityScale,
                amplitude: 0.2 * scale,
                frequency: 2.7,
                verticalOffset: 0.8,
                bottomFade: 0.4,
                treeDensity: 1,
                driftDuration: 20,
                showGrain: true,
                grainOpacity: colorScheme == .dark ? 0.014 : 0.03,
                crestColor: theme.forestMidColor,
                crestOpacity: 0.55 * opacityScale,
                crestWidth: 1
            )
            .frame(height: 180)

            // Bokashi gradient overlay
            LinearGradient(
                colors: forestGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        theme.forestMistColor.opacity(0.22),
                        theme.forestMidColor.opacity(0.10),
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

    private var forestGradientColors: [Color] {
        if isWeatherActive {
            if colorScheme == .dark {
                return [
                    atmosphere.waveColor(for: theme).opacity(DS.Opacity.strong),
                    theme.forestMistColor.opacity(DS.Opacity.medium),
                    .clear
                ]
            }
            return atmosphere.gradientColors(for: theme)
        }
        if colorScheme == .dark {
            return [
                theme.forestMistColor.opacity(DS.Opacity.medium),
                theme.forestMidColor.opacity(DS.Opacity.light),
                theme.forestDeepColor.opacity(DS.Opacity.subtle),
                .clear
            ]
        }
        return [
            theme.forestMidColor.opacity(DS.Opacity.medium),
            theme.forestDeepColor.opacity(DS.Opacity.subtle),
            .clear
        ]
    }
}

// MARK: - Forest Detail Background

/// Subtler 2-layer forest silhouette for push-destination detail screens.
/// Positioned at the bottom of the screen.
struct ForestDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.25 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Far — distant treeline
            ForestWaveOverlayView(
                color: theme.forestMistColor,
                opacity: 0.07 * visibilityBoost,
                amplitude: 0.20,
                frequency: 1.65,
                verticalOffset: 0.42,
                bottomFade: 0.5,
                treeDensity: 0.60,
                driftDuration: 22,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.09 * visibilityBoost,
                crestWidth: 1.0
            )
            .frame(height: 150)

            // Near — closer forest
            ForestWaveOverlayView(
                color: theme.forestDeepColor,
                opacity: 0.50 * visibilityBoost,
                amplitude: 0.30,
                frequency: 2.35,
                verticalOffset: 0.83,
                bottomFade: 0.45,
                treeDensity: 2.2,
                driftDuration: 18,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.13 * visibilityBoost,
                crestWidth: 1
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    (colorScheme == .dark ? theme.forestMistColor : theme.forestMidColor).opacity(DS.Opacity.light),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Forest Sheet Background

/// Lightest single-layer forest silhouette for sheet/modal presentations.
/// Minimal tree density, positioned at the bottom.
struct ForestSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.2 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            ForestWaveOverlayView(
                color: theme.forestMidColor,
                opacity: 0.10 * visibilityBoost,
                amplitude: 0.22,
                frequency: 0.6,
                verticalOffset: 0.40,
                bottomFade: 0.5,
                treeDensity: 0.60,
                driftDuration: 20,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.11 * visibilityBoost,
                crestWidth: 1.3
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    .clear,
                    (colorScheme == .dark ? theme.forestMistColor : theme.forestMidColor).opacity(DS.Opacity.light)
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("ForestTabWaveBackground") {
    ForestTabWaveBackground()
        .environment(\.appTheme, .forestGreen)
}

#Preview("Forest Tab — All Presets") {
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
            ForestTabWaveBackground()
                .environment(\.wavePreset, preset)
                .environment(\.appTheme, .forestGreen)
                .overlay(alignment: .center) {
                    Text(name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .tabItem { Text(name) }
        }
    }
}

#Preview("Forest Tab — Dark") {
    ForestTabWaveBackground()
        .environment(\.appTheme, .forestGreen)
        .preferredColorScheme(.dark)
}
