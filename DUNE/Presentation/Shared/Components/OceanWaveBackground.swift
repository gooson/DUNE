import SwiftUI

// MARK: - Ocean Tab Background

/// Multi-layer parallax ocean wave background for tab root screens.
///
/// Layers (back to front):
/// 1. **Deep** — slowest, dark navy, low amplitude
/// 2. **Mid** — reverse direction, rich teal, medium amplitude + stroke
/// 3. **Surface** — bright cyan, largest amplitude + stroke + foam gradient
struct OceanTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    /// Scale factor based on tab preset character.
    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2   // Rougher ocean
        case .today:    1.0
        case .wellness: 0.8   // Calmer deep sea
        case .life:     0.6   // Lake-like stillness
        }
    }

    var body: some View {
        let scale = intensityScale

        ZStack(alignment: .top) {
            // Layer 1: Deep (back)
            OceanWaveOverlayView(
                color: theme.oceanDeepColor,
                opacity: 0.07 * scale,
                amplitude: 0.026 * scale,
                frequency: 1.05,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                steepness: 0.12,
                crestHeight: 0.18 * scale,
                crestSharpness: 0.05 * scale,
                driftDuration: 18,
                reverseDirection: false,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 0.5,
                    opacity: 0.12 * scale
                )
            )
            .frame(height: 200)

            // Layer 2: Mid (reverse for cross-current)
            OceanWaveOverlayView(
                color: theme.oceanMidColor,
                opacity: 0.11 * scale,
                amplitude: 0.05 * scale,
                frequency: 1.65,
                verticalOffset: 0.5,
                bottomFade: 0.4,
                steepness: 0.24,
                harmonicOffset: .pi / 3,
                crestHeight: 0.3 * scale,
                crestSharpness: 0.09 * scale,
                driftDuration: 15,
                reverseDirection: true,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 1.1,
                    opacity: 0.24 * scale
                ),
                foamStyle: WaveFoamStyle(
                    color: theme.oceanFoamColor,
                    opacity: 0.2 * scale,
                    depth: 0.024
                )
            )
            .frame(height: 200)

            // Layer 3: Surface (front, most visible)
            OceanWaveOverlayView(
                color: theme.oceanSurfaceColor,
                opacity: 0.28 * scale,
                amplitude: 0.13 * scale,
                frequency: 2.35,
                verticalOffset: 0.56,
                bottomFade: 0.4,
                steepness: 0.54,
                crestHeight: 0.5 * scale,
                crestSharpness: 0.16 * scale,
                driftDuration: 12,
                reverseDirection: false,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 2.5,
                    opacity: 0.68 * scale
                ),
                foamStyle: WaveFoamStyle(
                    color: theme.oceanFoamColor,
                    opacity: 0.64 * scale,
                    depth: 0.08
                )
            )
            .frame(height: 200)

            // Background gradient
            LinearGradient(
                colors: oceanGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }

    private var oceanGradientColors: [Color] {
        if isWeatherActive {
            return atmosphere.gradientColors(for: theme)
        }
        return [
            theme.oceanSurfaceColor.opacity(DS.Opacity.medium),
            theme.oceanDeepColor.opacity(DS.Opacity.subtle),
            .clear
        ]
    }
}

// MARK: - Ocean Detail Background

/// Subtler 3-layer ocean wave for push-destination detail screens.
/// Scaled down: amplitude 50%, opacity 70%, stroke only (no foam gradient).
struct OceanDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            // Deep
            OceanWaveOverlayView(
                color: theme.oceanDeepColor,
                opacity: 0.06,
                amplitude: 0.02,
                frequency: 1.0,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                steepness: 0.1,
                crestHeight: 0.14,
                crestSharpness: 0.03,
                driftDuration: 16,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 0.5,
                    opacity: 0.12
                )
            )
            .frame(height: 150)

            // Mid
            OceanWaveOverlayView(
                color: theme.oceanMidColor,
                opacity: 0.095,
                amplitude: 0.033,
                frequency: 1.5,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                steepness: 0.25,
                crestHeight: 0.23,
                crestSharpness: 0.06,
                driftDuration: 14,
                reverseDirection: true,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 0.8,
                    opacity: 0.18
                )
            )
            .frame(height: 150)

            // Surface
            OceanWaveOverlayView(
                color: theme.oceanSurfaceColor,
                opacity: 0.16,
                amplitude: 0.06,
                frequency: 2.0,
                verticalOffset: 0.55,
                bottomFade: 0.5,
                steepness: 0.44,
                crestHeight: 0.34,
                crestSharpness: 0.12,
                driftDuration: 12,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 1.5,
                    opacity: 0.42
                )
            )
            .frame(height: 150)

            LinearGradient(
                colors: [theme.oceanSurfaceColor.opacity(DS.Opacity.light), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Ocean Sheet Background

/// Lightest 2-layer ocean wave for sheet/modal presentations.
/// Scaled down further: amplitude 40%, opacity 60%. Stroke only.
struct OceanSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            // Mid
            OceanWaveOverlayView(
                color: theme.oceanMidColor,
                opacity: 0.07,
                amplitude: 0.024,
                frequency: 1.5,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                steepness: 0.2,
                crestHeight: 0.12,
                crestSharpness: 0.03,
                driftDuration: 14,
                reverseDirection: true,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 0.5,
                    opacity: 0.12
                )
            )
            .frame(height: 120)

            // Surface
            OceanWaveOverlayView(
                color: theme.oceanSurfaceColor,
                opacity: 0.14,
                amplitude: 0.05,
                frequency: 2.0,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                steepness: 0.38,
                crestHeight: 0.24,
                crestSharpness: 0.1,
                driftDuration: 12,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 1.2,
                    opacity: 0.36
                )
            )
            .frame(height: 120)

            LinearGradient(
                colors: [theme.oceanSurfaceColor.opacity(DS.Opacity.light), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}
