import SwiftUI
import UIKit

// MARK: - Forest Wave-Specific Colors (File-Private)

/// Forest wave layer colors are only consumed by forest backgrounds.
/// Kept file-private to avoid polluting the shared AppTheme extension.
private extension AppTheme {
    var forestDeepColor: Color { Color("ForestDeep") }
    var forestMidColor: Color { Color("ForestMid") }
    var forestMistColor: Color { Color("ForestMist") }
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
    var ruggedness: CGFloat = 0.3
    var treeDensity: CGFloat = 0.0
    var driftDuration: Double = 8
    var showGrain: Bool = false
    var grainOpacity: Double = 0.04
    var crestColor: Color? = nil
    var crestOpacity: Double = 0.18
    var crestWidth: CGFloat = 1.6

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .bottomFadeMask(bottomFade)

            if let crestColor {
                ZStack {
                    // Wide translucent crest band.
                    ForestSilhouetteShape(
                        amplitude: amplitude,
                        frequency: frequency,
                        phase: phase,
                        verticalOffset: verticalOffset,
                        ruggedness: ruggedness,
                        treeDensity: treeDensity
                    )
                    .stroke(
                        crestColor.opacity(crestOpacity * 0.58),
                        style: StrokeStyle(lineWidth: crestWidth * 3.4, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 1.35)

                    // Mid crest veil.
                    ForestSilhouetteShape(
                        amplitude: amplitude,
                        frequency: frequency,
                        phase: phase,
                        verticalOffset: verticalOffset,
                        ruggedness: ruggedness,
                        treeDensity: treeDensity
                    )
                    .stroke(
                        crestColor.opacity(crestOpacity * 0.42),
                        style: StrokeStyle(lineWidth: crestWidth * 1.9, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 0.65)

                    // Core crest highlight line.
                    ForestSilhouetteShape(
                        amplitude: amplitude,
                        frequency: frequency,
                        phase: phase,
                        verticalOffset: verticalOffset,
                        ruggedness: ruggedness,
                        treeDensity: treeDensity
                    )
                    .stroke(
                        crestColor.opacity(crestOpacity),
                        style: StrokeStyle(lineWidth: crestWidth * 0.95, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 0.22)
                }
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.9)
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
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            Task { @MainActor in
                phase = 0
                withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                    phase = 2 * .pi
                }
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
        let size = CGSize(width: UIScreen.main.bounds.width, height: 200)
        let step: CGFloat = 6
        let cols = Int(size.width / step)
        let rows = Int(size.height / step)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            for row in 0..<rows {
                for col in 0..<cols {
                    let seed = Double(row * 997 + col * 131)
                    let noise = sin(seed * 0.06) * sin(seed * 0.041) * sin(seed * 0.019)
                    let alpha = abs(noise) * 0.13
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
/// 1. **Far** — slowest, misty, smooth hills (distant mountains)
/// 2. **Mid** — medium speed, moderate ruggedness (mid-range forest)
/// 3. **Near** — fastest, rugged with tree silhouettes (foreground forest)
///
/// Includes ukiyo-e grain texture overlay and bokashi gradient.
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
            // Layer 1: Far — distant misty mountains
            ForestWaveOverlayView(
                color: theme.forestMistColor,
                opacity: 0.12 * opacityScale,
                amplitude: 0.045 * scale,
                frequency: 0.62,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                ruggedness: 0.03,
                treeDensity: 0.03,
                driftDuration: 22,
                crestColor: .white,
                crestOpacity: 0.2 * opacityScale,
                crestWidth: 2.0
            )
            .frame(height: 200)

            // Layer 2: Mid — middle forest
            ForestWaveOverlayView(
                color: theme.forestMidColor,
                opacity: 0.17 * opacityScale,
                amplitude: 0.075 * scale,
                frequency: 0.95,
                verticalOffset: 0.5,
                bottomFade: 0.4,
                ruggedness: 0.12,
                treeDensity: 0.08,
                driftDuration: 18,
                crestColor: .white,
                crestOpacity: 0.28 * opacityScale,
                crestWidth: 2.6
            )
            .frame(height: 200)

            // Layer 3: Near — foreground forest with trees
            ForestWaveOverlayView(
                color: theme.forestDeepColor,
                opacity: 0.24 * opacityScale,
                amplitude: 0.115 * scale,
                frequency: 1.25,
                verticalOffset: 0.55,
                bottomFade: 0.4,
                ruggedness: 0.18,
                treeDensity: 0.12,
                driftDuration: 14,
                showGrain: true,
                grainOpacity: colorScheme == .dark ? 0.028 : 0.045,
                crestColor: .white,
                crestOpacity: 0.36 * opacityScale,
                crestWidth: 3.6
            )
            .frame(height: 200)

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
/// Scaled down: amplitude 50%, opacity 70%.
struct ForestDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.25 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Far
            ForestWaveOverlayView(
                color: theme.forestMistColor,
                opacity: 0.08 * visibilityBoost,
                amplitude: 0.03,
                frequency: 0.65,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                ruggedness: 0.03,
                treeDensity: 0.02,
                driftDuration: 20,
                crestColor: .white,
                crestOpacity: 0.16 * visibilityBoost,
                crestWidth: 1.8
            )
            .frame(height: 150)

            // Near
            ForestWaveOverlayView(
                color: theme.forestDeepColor,
                opacity: 0.15 * visibilityBoost,
                amplitude: 0.06,
                frequency: 1.0,
                verticalOffset: 0.55,
                bottomFade: 0.5,
                ruggedness: 0.14,
                treeDensity: 0.1,
                driftDuration: 16,
                crestColor: .white,
                crestOpacity: 0.24 * visibilityBoost,
                crestWidth: 2.4
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
/// Minimal ruggedness, no grain.
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
                opacity: 0.12 * visibilityBoost,
                amplitude: 0.045,
                frequency: 0.9,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                ruggedness: 0.1,
                treeDensity: 0.08,
                driftDuration: 18,
                crestColor: .white,
                crestOpacity: 0.2 * visibilityBoost,
                crestWidth: 2.0
            )
            .frame(height: 120)

            LinearGradient(
                colors: [
                    (colorScheme == .dark ? theme.forestMistColor : theme.forestMidColor).opacity(DS.Opacity.light),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}
