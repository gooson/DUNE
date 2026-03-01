import SwiftUI

// MARK: - Ocean Tab Background

/// Multi-layer parallax ocean wave background for tab root screens.
///
/// Layers (back to front):
/// 1. **Deep** — slowest, dark navy, low amplitude
/// 2. **Mid** — reverse direction, rich teal, medium amplitude + stroke
/// 3. **Surface** — fastest, bright cyan, largest amplitude + stroke + foam gradient
/// 4. **Big wave** — dramatic curling wave accent (excluded from .life)
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

    /// Curl count: big wave crests on surface layer.
    /// Excluded from .life (lake-like stillness).
    private var curlCount: Int {
        switch preset {
        case .train:              2    // Rougher ocean
        case .today, .wellness:   1
        case .life:               0    // Lake-like stillness
        }
    }

    var body: some View {
        let scale = intensityScale

        ZStack(alignment: .top) {
            // Layer 1: Deep (back)
            OceanWaveOverlayView(
                color: theme.oceanDeepColor,
                opacity: 0.07 * scale,
                amplitude: 0.025 * scale,
                frequency: 1.0,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                steepness: 0.1,
                crestHeight: 0.15 * scale,
                crestSharpness: 0.03 * scale,
                driftDuration: 10,
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
                amplitude: 0.045 * scale,
                frequency: 1.5,
                verticalOffset: 0.5,
                bottomFade: 0.4,
                steepness: 0.2,
                harmonicOffset: .pi / 3,
                crestHeight: 0.25 * scale,
                crestSharpness: 0.06 * scale,
                driftDuration: 7,
                reverseDirection: true,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 1.0,
                    opacity: 0.2 * scale
                ),
                foamStyle: WaveFoamStyle(
                    color: theme.oceanFoamColor,
                    opacity: 0.15 * scale,
                    depth: 0.02
                )
            )
            .frame(height: 200)

            // Layer 3: Surface (front, fastest, most visible, with curl crests)
            OceanWaveOverlayView(
                color: theme.oceanSurfaceColor,
                opacity: 0.15 * scale,
                amplitude: 0.07 * scale,
                frequency: 2.0,
                verticalOffset: 0.55,
                bottomFade: 0.4,
                steepness: 0.40,
                crestHeight: 0.3 * scale,
                crestSharpness: 0.12 * scale,
                driftDuration: 5,
                reverseDirection: false,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 1.5,
                    opacity: 0.35 * scale
                ),
                foamStyle: WaveFoamStyle(
                    color: theme.oceanFoamColor,
                    opacity: 0.30 * scale,
                    depth: 0.035
                ),
                curlCount: curlCount,
                curlHeight: 2.2 * scale,
                curlWidth: 0.15
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
            return atmosphere.gradientColors
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
                opacity: 0.05,
                amplitude: 0.015,
                frequency: 1.0,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                steepness: 0.1,
                crestHeight: 0.1,
                crestSharpness: 0.02,
                driftDuration: 10,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 0.5,
                    opacity: 0.1
                )
            )
            .frame(height: 150)

            // Mid
            OceanWaveOverlayView(
                color: theme.oceanMidColor,
                opacity: 0.08,
                amplitude: 0.025,
                frequency: 1.5,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                steepness: 0.2,
                crestHeight: 0.17,
                crestSharpness: 0.04,
                driftDuration: 7,
                reverseDirection: true,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 0.8,
                    opacity: 0.15
                )
            )
            .frame(height: 150)

            // Surface
            OceanWaveOverlayView(
                color: theme.oceanSurfaceColor,
                opacity: 0.10,
                amplitude: 0.035,
                frequency: 2.0,
                verticalOffset: 0.55,
                bottomFade: 0.5,
                steepness: 0.3,
                crestHeight: 0.2,
                crestSharpness: 0.07,
                driftDuration: 5,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 1.0,
                    opacity: 0.25
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
                opacity: 0.06,
                amplitude: 0.018,
                frequency: 1.5,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                steepness: 0.15,
                crestHeight: 0.08,
                crestSharpness: 0.02,
                driftDuration: 7,
                reverseDirection: true,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 0.5,
                    opacity: 0.1
                )
            )
            .frame(height: 120)

            // Surface
            OceanWaveOverlayView(
                color: theme.oceanSurfaceColor,
                opacity: 0.09,
                amplitude: 0.028,
                frequency: 2.0,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                steepness: 0.25,
                crestHeight: 0.12,
                crestSharpness: 0.04,
                driftDuration: 5,
                strokeStyle: WaveStrokeStyle(
                    color: theme.oceanFoamColor,
                    width: 0.8,
                    opacity: 0.18
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
