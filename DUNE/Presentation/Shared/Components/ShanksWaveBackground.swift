import SwiftUI

// MARK: - Shanks Tab Background

/// Multi-layer parallax crimson wave background for tab root screens.
///
/// Layers (back to front):
/// 1. **Deep** — slow, dark waves (pirate flag silhouette horizon)
/// 2. **Core** — crimson mid-layer with gold crest highlights
/// 3. **Glow** — bright scarlet foreground with shimmer
///
/// Reuses `DesertDuneOverlayView` for the wave shape, parameterized with
/// Shanks Red Hair Pirates theme colors: deep navy, crimson, and gold.
struct ShanksTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2   // Battle intensity
        case .today:    1.0
        case .wellness: 0.8   // Calm seas
        case .life:     0.6   // Harbor stillness
        }
    }

    private var darkBoost: Double {
        colorScheme == .dark ? 1.12 : 1.0
    }

    private var resolvedColor: Color {
        isWeatherActive ? atmosphere.waveColor : color
    }

    var body: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * darkBoost

        ZStack(alignment: .top) {
            // Layer 1: Deep — broad, dark horizon (pirate flag backdrop)
            DesertDuneOverlayView(
                color: theme.shanksDeepColor,
                opacity: 0.10 * opacityScale,
                amplitude: 0.042 * scale,
                frequency: 0.78,
                verticalOffset: 0.34,
                bottomFade: 0.52,
                skewness: 0.22,
                skewOffset: .pi / 5,
                driftDuration: 20,
                crestColor: theme.shanksCoreColor,
                crestOpacity: 0.10 * opacityScale,
                crestWidth: 0.8
            )
            .frame(height: 200)

            // Layer 2: Core — crimson mid-layer with gold crest
            DesertDuneOverlayView(
                color: theme.shanksCoreColor,
                opacity: 0.16 * opacityScale,
                amplitude: 0.075 * scale,
                frequency: 1.25,
                verticalOffset: 0.50,
                bottomFade: 0.46,
                skewness: 0.18,
                skewOffset: .pi / 4,
                driftDuration: 14,
                crestColor: theme.bronzeColor,
                crestOpacity: 0.18 * opacityScale,
                crestWidth: 1.2
            )
            .frame(height: 200)

            // Layer 3: Glow — bright scarlet foreground
            DesertDuneOverlayView(
                color: resolvedColor,
                opacity: 0.20 * opacityScale,
                amplitude: 0.094 * scale,
                frequency: 1.6,
                verticalOffset: 0.60,
                bottomFade: 0.42,
                skewness: 0.12,
                skewOffset: .pi / 3,
                driftDuration: 11,
                showShimmer: false,
                crestColor: theme.shanksGlowColor,
                crestOpacity: 0.24 * opacityScale,
                crestWidth: 1.5
            )
            .frame(height: 200)

            // Background gradient
            LinearGradient(
                colors: shanksGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }

    private var shanksGradientColors: [Color] {
        if isWeatherActive {
            return atmosphere.gradientColors
        }
        let darkAlpha = colorScheme == .dark
        return [
            theme.shanksDeepColor.opacity(darkAlpha ? 0.36 : 0.28),
            theme.shanksCoreColor.opacity(darkAlpha ? 0.22 : 0.16),
            theme.shanksGlowColor.opacity(darkAlpha ? 0.12 : 0.08),
            .clear
        ]
    }
}

// MARK: - Shanks Detail Background

/// Subtler two-layer crimson wave for push-destination detail screens.
struct ShanksDetailWaveBackground: View {
    @Environment(\.waveColor) private var color
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            // Core crimson layer
            DesertDuneOverlayView(
                color: theme.shanksCoreColor,
                opacity: 0.10,
                amplitude: 0.038,
                frequency: 1.0,
                verticalOffset: 0.44,
                bottomFade: 0.54,
                skewness: 0.18,
                driftDuration: 16,
                crestColor: theme.bronzeColor,
                crestOpacity: 0.14,
                crestWidth: 0.9
            )
            .frame(height: 150)

            // Scarlet foreground
            DesertDuneOverlayView(
                color: color,
                opacity: 0.15,
                amplitude: 0.060,
                frequency: 1.5,
                verticalOffset: 0.54,
                bottomFade: 0.48,
                skewness: 0.14,
                driftDuration: 12,
                crestColor: theme.shanksGlowColor,
                crestOpacity: 0.20,
                crestWidth: 1.2
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    theme.shanksDeepColor.opacity(colorScheme == .dark ? 0.26 : 0.18),
                    theme.shanksCoreColor.opacity(colorScheme == .dark ? 0.14 : 0.10),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Shanks Sheet Background

/// Lightest single-layer crimson wave for sheet/modal presentations.
struct ShanksSheetWaveBackground: View {
    @Environment(\.waveColor) private var color
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            DesertDuneOverlayView(
                color: theme.shanksCoreColor,
                opacity: 0.08,
                amplitude: 0.032,
                frequency: 0.9,
                verticalOffset: 0.48,
                bottomFade: 0.52,
                skewness: 0.16,
                driftDuration: 18,
                crestColor: theme.bronzeColor,
                crestOpacity: 0.12,
                crestWidth: 0.9
            )
            .frame(height: 120)

            LinearGradient(
                colors: [
                    theme.shanksDeepColor.opacity(colorScheme == .dark ? 0.20 : 0.14),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}
