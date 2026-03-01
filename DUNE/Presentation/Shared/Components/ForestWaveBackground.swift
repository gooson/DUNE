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
                        crestColor.opacity(crestOpacity * 0.48),
                        style: StrokeStyle(lineWidth: crestWidth * 2.6, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 1.2)

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
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
        .onAppear {
            guard !reduceMotion, driftDuration > 0 else { return }
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
        colorScheme == .dark ? 1.15 : 1.0
    }

    /// Scale factor based on tab preset character.
    private var intensityScale: CGFloat {
        switch preset {
        case .train:    0.95  // Dense forest
        case .today:    0.88
        case .wellness: 0.80  // Gentle grove
        case .life:     0.70  // Misty meadow
        }
    }

    var body: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * visibilityBoost

        ZStack(alignment: .top) {
            // Layer 1: Far — distant misty mountains
            ForestWaveOverlayView(
                color: theme.forestMistColor,
                opacity: 0.22 * opacityScale,
                amplitude: 0.08 * scale,
                frequency: 0.62,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                ruggedness: 0.05,
                treeDensity: 0.06,
                driftDuration: 22,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.20 * opacityScale,
                crestWidth: 1.3
            )
            .frame(height: 220)

            // Layer 2: Mid — middle forest
            ForestWaveOverlayView(
                color: theme.forestMidColor,
                opacity: 0.30 * opacityScale,
                amplitude: 0.12 * scale,
                frequency: 0.95,
                verticalOffset: 0.48,
                bottomFade: 0.4,
                ruggedness: 0.15,
                treeDensity: 0.12,
                driftDuration: 18,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.26 * opacityScale,
                crestWidth: 1.65
            )
            .frame(height: 240)

            // Layer 3: Near — foreground forest with trees
            ForestWaveOverlayView(
                color: theme.forestDeepColor,
                opacity: 0.40 * opacityScale,
                amplitude: 0.16 * scale,
                frequency: 1.25,
                verticalOffset: 0.52,
                bottomFade: 0.4,
                ruggedness: 0.22,
                treeDensity: 0.18,
                driftDuration: 14,
                showGrain: true,
                grainOpacity: colorScheme == .dark ? 0.02 : 0.04,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.30 * opacityScale,
                crestWidth: 2.0
            )
            .frame(height: 280)

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
            // Far — distant treeline
            ForestWaveOverlayView(
                color: theme.forestMistColor,
                opacity: 0.18 * visibilityBoost,
                amplitude: 0.065,
                frequency: 0.62,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                ruggedness: 0.04,
                treeDensity: 0.05,
                driftDuration: 22,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.16 * visibilityBoost,
                crestWidth: 1.2
            )
            .frame(height: 180)

            // Near — closer forest
            ForestWaveOverlayView(
                color: theme.forestDeepColor,
                opacity: 0.28 * visibilityBoost,
                amplitude: 0.10,
                frequency: 1.0,
                verticalOffset: 0.5,
                bottomFade: 0.4,
                ruggedness: 0.14,
                treeDensity: 0.10,
                driftDuration: 18,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.22 * visibilityBoost,
                crestWidth: 1.5
            )
            .frame(height: 180)

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
                opacity: 0.20 * visibilityBoost,
                amplitude: 0.075,
                frequency: 0.8,
                verticalOffset: 0.45,
                bottomFade: 0.5,
                ruggedness: 0.08,
                treeDensity: 0.06,
                driftDuration: 20,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.18 * visibilityBoost,
                crestWidth: 1.3
            )
            .frame(height: 170)

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
