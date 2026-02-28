import SwiftUI

// MARK: - Ocean Tab Background

/// 4-layer parallax ocean wave background for tab root screens.
///
/// Layers (back to front):
/// 1. **Deep** — slowest, dark navy, low amplitude
/// 2. **Mid** — reverse direction, rich teal, medium amplitude
/// 3. **Surface** — fastest, bright cyan, largest amplitude + swell modulation
/// 4. **Foam** — thin white crest highlight tracking surface wave
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

    private var showFoam: Bool {
        preset == .train || preset == .today
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
                driftDuration: 10,
                reverseDirection: false
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
                driftDuration: 7,
                reverseDirection: true
            )
            .frame(height: 200)

            // Layer 3: Surface (front, fastest)
            OceanWaveOverlayView(
                color: theme.oceanSurfaceColor,
                opacity: 0.15 * scale,
                amplitude: 0.07 * scale,
                frequency: 2.0,
                verticalOffset: 0.55,
                bottomFade: 0.4,
                steepness: 0.35,
                driftDuration: 5,
                reverseDirection: false
            )
            .frame(height: 200)

            // Layer 4: Foam (crest highlight)
            if showFoam {
                OceanWaveOverlayView(
                    color: theme.oceanFoamColor,
                    opacity: 0.06 * scale,
                    amplitude: 0.008 * scale,
                    frequency: 2.0,
                    verticalOffset: 0.48,
                    bottomFade: 0.3,
                    steepness: 0.0,
                    driftDuration: 5,
                    reverseDirection: false
                )
                .frame(height: 200)
            }

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
/// Scaled down: amplitude 50%, opacity 70%.
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
                driftDuration: 10
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
                driftDuration: 7,
                reverseDirection: true
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
                driftDuration: 5
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
/// Scaled down further: amplitude 40%, opacity 60%.
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
                driftDuration: 7,
                reverseDirection: true
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
                driftDuration: 5
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
