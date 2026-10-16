import SwiftUI

// MARK: - Solar Tab Background

/// A fixed solar core with slowly breathing light trails for tab root screens.
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
            SolarCoronaScene(intensity: opacityScale)
                .frame(height: 230)

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
            SolarCoronaScene(intensity: 0.65 * visibilityBoost)
                .frame(height: 170)

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
            SolarCoronaScene(intensity: 0.45 * visibilityBoost)
                .frame(height: 140)

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

// MARK: - Solar Scene

/// The core stays fixed while its surrounding trails breathe by a few points.
private struct SolarCoronaScene: View {
    let intensity: Double

    @Environment(\.appTheme) private var theme
    @Environment(\.waveReducedMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !reduceMotion && scenePhase == .active {
                    lightTrails
                        .phaseAnimator([false, true]) { content, expanded in
                            content
                                .scaleEffect(expanded ? 1.05 : 1)
                                .rotationEffect(.degrees(expanded ? 3 : -3))
                        } animation: { _ in
                            .easeInOut(duration: 7)
                        }
                } else {
                    lightTrails
                }

                // A steady core avoids suggesting that a health value is pulsing.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [theme.solarGlowColor, theme.solarCoreColor, theme.solarEmberColor],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 58, height: 58)
                    .opacity(0.40 * intensity)
            }
            .position(x: geometry.size.width * 0.78, y: geometry.size.height * 0.38)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var lightTrails: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.solarCoreColor.opacity(0.20 * intensity), .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            Ellipse()
                .trim(from: 0.08, to: 0.84)
                .stroke(
                    theme.solarGlowColor.opacity(0.34 * intensity),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 170, height: 90)
                .rotationEffect(.degrees(-24))

            Ellipse()
                .trim(from: 0.24, to: 0.94)
                .stroke(
                    theme.solarCoreColor.opacity(0.22 * intensity),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: 220, height: 130)
                .rotationEffect(.degrees(18))
        }
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
