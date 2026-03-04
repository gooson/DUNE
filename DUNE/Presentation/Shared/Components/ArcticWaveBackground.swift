import SwiftUI

// MARK: - Arctic Tab Background

/// Multi-layer aurora-inspired background for tab root screens.
///
/// Layers (back to front):
/// 1. **Deep** — distant arctic haze, broad slow waves
/// 2. **Aurora** — mid-layer aurora ribbon with glow
/// 3. **Frost** — foreground frost highlight, sharpest
struct ArcticTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.3 : 1.0
    }

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
            // Layer 1: Deep — distant arctic haze
            WaveOverlayView(
                color: theme.arcticDeepColor,
                opacity: 0.10 * opacityScale,
                amplitude: 0.04 * scale,
                frequency: 0.8,
                verticalOffset: 0.35,
                bottomFade: 0.5
            )
            .frame(height: 180)

            // Layer 2: Aurora — mid-layer aurora ribbon
            WaveOverlayView(
                color: theme.arcticAuroraColor,
                opacity: 0.18 * opacityScale,
                amplitude: 0.06 * scale,
                frequency: 1.5,
                verticalOffset: 0.50,
                bottomFade: 0.4
            )
            .frame(height: 170)

            // Layer 3: Frost — foreground frost highlight
            WaveOverlayView(
                color: theme.arcticFrostColor,
                opacity: 0.08 * opacityScale,
                amplitude: 0.03 * scale,
                frequency: 2.5,
                verticalOffset: 0.65,
                bottomFade: 0.35
            )
            .frame(height: 140)

            // Background gradient
            LinearGradient(
                colors: arcticGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        theme.arcticAuroraColor.opacity(0.15),
                        theme.arcticDeepColor.opacity(0.08),
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

    private var arcticGradientColors: [Color] {
        if isWeatherActive {
            if colorScheme == .dark {
                return [
                    atmosphere.waveColor(for: theme).opacity(DS.Opacity.strong),
                    theme.arcticDeepColor.opacity(DS.Opacity.medium),
                    .clear
                ]
            }
            return atmosphere.gradientColors(for: theme)
        }
        if colorScheme == .dark {
            return [
                theme.arcticDeepColor.opacity(DS.Opacity.medium),
                theme.arcticAuroraColor.opacity(DS.Opacity.light),
                .clear
            ]
        }
        return [
            theme.arcticAuroraColor.opacity(DS.Opacity.medium),
            theme.arcticDeepColor.opacity(DS.Opacity.subtle),
            .clear
        ]
    }
}

// MARK: - Arctic Detail Background

/// Subtler 2-layer aurora for push-destination detail screens.
struct ArcticDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.25 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Deep haze
            WaveOverlayView(
                color: theme.arcticDeepColor,
                opacity: 0.07 * visibilityBoost,
                amplitude: 0.03,
                frequency: 1.0,
                verticalOffset: 0.40,
                bottomFade: 0.5
            )
            .frame(height: 150)

            // Aurora glow
            WaveOverlayView(
                color: theme.arcticAuroraColor,
                opacity: 0.12 * visibilityBoost,
                amplitude: 0.04,
                frequency: 1.8,
                verticalOffset: 0.55,
                bottomFade: 0.45
            )
            .frame(height: 140)

            LinearGradient(
                colors: [
                    (colorScheme == .dark ? theme.arcticAuroraColor : theme.arcticDeepColor).opacity(DS.Opacity.light),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Arctic Sheet Background

/// Lightest single-layer frost for sheet/modal presentations.
struct ArcticSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.2 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            WaveOverlayView(
                color: theme.arcticDeepColor,
                opacity: 0.06 * visibilityBoost,
                amplitude: 0.025,
                frequency: 0.9,
                verticalOffset: 0.45,
                bottomFade: 0.5
            )
            .frame(height: 130)

            LinearGradient(
                colors: [
                    .clear,
                    (colorScheme == .dark ? theme.arcticAuroraColor : theme.arcticDeepColor).opacity(DS.Opacity.light)
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("ArcticTabWaveBackground") {
    ArcticTabWaveBackground()
        .environment(\.appTheme, .arcticDawn)
}

#Preview("Arctic Tab — Dark") {
    ArcticTabWaveBackground()
        .environment(\.appTheme, .arcticDawn)
        .preferredColorScheme(.dark)
}
