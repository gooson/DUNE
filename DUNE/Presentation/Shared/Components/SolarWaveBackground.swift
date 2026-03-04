import SwiftUI

// MARK: - Solar Tab Background

/// Multi-layer solar flare background for tab root screens.
///
/// Layers (back to front):
/// 1. **Ember** — distant warm glow, broad slow waves
/// 2. **Core** — mid-layer solar core energy
/// 3. **Glow** — foreground bright highlight flare
struct SolarTabWaveBackground: View {
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
            // Layer 1: Ember — distant warm glow
            WaveOverlayView(
                color: theme.solarEmberColor,
                opacity: 0.12 * opacityScale,
                amplitude: 0.05 * scale,
                frequency: 0.7,
                verticalOffset: 0.35,
                bottomFade: 0.5
            )
            .frame(height: 190)

            // Layer 2: Core — mid-layer solar energy
            WaveOverlayView(
                color: theme.solarCoreColor,
                opacity: 0.16 * opacityScale,
                amplitude: 0.07 * scale,
                frequency: 1.6,
                verticalOffset: 0.48,
                bottomFade: 0.4
            )
            .frame(height: 170)

            // Layer 3: Glow — foreground bright flare
            WaveOverlayView(
                color: theme.solarGlowColor,
                opacity: 0.07 * opacityScale,
                amplitude: 0.03 * scale,
                frequency: 2.8,
                verticalOffset: 0.62,
                bottomFade: 0.35
            )
            .frame(height: 140)

            // Background gradient
            LinearGradient(
                colors: solarGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        theme.solarCoreColor.opacity(0.14),
                        theme.solarEmberColor.opacity(0.07),
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

    private var solarGradientColors: [Color] {
        if isWeatherActive {
            if colorScheme == .dark {
                return [
                    atmosphere.waveColor(for: theme).opacity(DS.Opacity.strong),
                    theme.solarEmberColor.opacity(DS.Opacity.medium),
                    .clear
                ]
            }
            return atmosphere.gradientColors(for: theme)
        }
        if colorScheme == .dark {
            return [
                theme.solarEmberColor.opacity(DS.Opacity.medium),
                theme.solarCoreColor.opacity(DS.Opacity.light),
                .clear
            ]
        }
        return [
            theme.solarCoreColor.opacity(DS.Opacity.medium),
            theme.solarEmberColor.opacity(DS.Opacity.subtle),
            .clear
        ]
    }
}

// MARK: - Solar Detail Background

/// Subtler 2-layer solar warmth for push-destination detail screens.
struct SolarDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.25 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Ember glow
            WaveOverlayView(
                color: theme.solarEmberColor,
                opacity: 0.08 * visibilityBoost,
                amplitude: 0.035,
                frequency: 0.9,
                verticalOffset: 0.40,
                bottomFade: 0.5
            )
            .frame(height: 150)

            // Core warmth
            WaveOverlayView(
                color: theme.solarCoreColor,
                opacity: 0.10 * visibilityBoost,
                amplitude: 0.045,
                frequency: 1.7,
                verticalOffset: 0.55,
                bottomFade: 0.45
            )
            .frame(height: 140)

            LinearGradient(
                colors: [
                    (colorScheme == .dark ? theme.solarCoreColor : theme.solarEmberColor).opacity(DS.Opacity.light),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Solar Sheet Background

/// Lightest single-layer solar warmth for sheet/modal presentations.
struct SolarSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.2 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            WaveOverlayView(
                color: theme.solarEmberColor,
                opacity: 0.06 * visibilityBoost,
                amplitude: 0.025,
                frequency: 0.8,
                verticalOffset: 0.45,
                bottomFade: 0.5
            )
            .frame(height: 130)

            LinearGradient(
                colors: [
                    .clear,
                    (colorScheme == .dark ? theme.solarCoreColor : theme.solarEmberColor).opacity(DS.Opacity.light)
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("SolarTabWaveBackground") {
    SolarTabWaveBackground()
        .environment(\.appTheme, .solarPop)
}

#Preview("Solar Tab — Dark") {
    SolarTabWaveBackground()
        .environment(\.appTheme, .solarPop)
        .preferredColorScheme(.dark)
}
