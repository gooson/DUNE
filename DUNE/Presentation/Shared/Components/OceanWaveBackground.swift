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

// MARK: - Arctic Ribbon Shape

/// Layered ribbon wave used by Arctic Dawn backgrounds.
struct ArcticRibbonShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat
    let ridge: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let points: [(x: CGFloat, angle: CGFloat)]
    private static let sampleCount = 120

    init(
        amplitude: CGFloat = 0.05,
        frequency: CGFloat = 1.8,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.52,
        ridge: CGFloat = 0.22
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.ridge = ridge

        let count = Self.sampleCount
        var pts: [(x: CGFloat, angle: CGFloat)] = []
        pts.reserveCapacity(count + 1)
        for i in 0...count {
            let x = CGFloat(i) / CGFloat(count)
            let angle = x * frequency * 2 * .pi
            pts.append((x: x, angle: angle))
        }
        self.points = pts
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var path = Path()
        for (idx, pt) in points.enumerated() {
            let base = sin(pt.angle + phase)
            let harmonic = sin(pt.angle * 2.15 + phase * 0.84)
            let shimmer = cos(pt.angle * 0.72 + phase * 0.33)
            let y = centerY + amp * (base * 0.72 + harmonic * ridge + shimmer * 0.08)
            let x = pt.x * rect.width

            if idx == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Arctic Ribbon Overlay

struct ArcticRibbonOverlayView: View {
    var color: Color
    var opacity: Double = 0.13
    var amplitude: CGFloat = 0.06
    var frequency: CGFloat = 1.6
    var verticalOffset: CGFloat = 0.52
    var bottomFade: CGFloat = 0.48
    var ridge: CGFloat = 0.22
    var driftDuration: Double = 12
    var reverseDirection: Bool = false
    var strokeColor: Color? = nil
    var strokeOpacity: Double = 0.2
    var strokeWidth: CGFloat = 1.0

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetPhase: CGFloat {
        (reverseDirection ? -1 : 1) * 2 * .pi
    }

    var body: some View {
        let ribbon = ArcticRibbonShape(
            amplitude: amplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset,
            ridge: ridge
        )

        ZStack {
            ribbon
                .fill(color.opacity(opacity))
                .bottomFadeMask(bottomFade)

            if let strokeColor {
                ribbon
                    .stroke(
                        strokeColor.opacity(strokeOpacity),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                    )
                    .bottomFadeMask(bottomFade)
                    .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion, driftDuration > 0 else { return }
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = targetPhase
            }
        }
        .onAppear {
            guard !reduceMotion, driftDuration > 0 else { return }
            Task { @MainActor in
                phase = 0
                withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                    phase = targetPhase
                }
            }
        }
    }
}

// MARK: - Arctic Dawn Backgrounds

struct ArcticTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme

    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.15
        case .today:    1.0
        case .wellness: 0.82
        case .life:     0.68
        }
    }

    var body: some View {
        let scale = intensityScale

        ZStack(alignment: .top) {
            ArcticRibbonOverlayView(
                color: theme.arcticDeepColor,
                opacity: 0.08 * scale,
                amplitude: 0.034 * scale,
                frequency: 0.95,
                verticalOffset: 0.40,
                bottomFade: 0.52,
                ridge: 0.16,
                driftDuration: 18,
                strokeColor: theme.arcticFrostColor,
                strokeOpacity: 0.12 * scale,
                strokeWidth: 0.8
            )
            .frame(height: 200)

            ArcticRibbonOverlayView(
                color: theme.arcticAuroraColor,
                opacity: 0.17 * scale,
                amplitude: 0.074 * scale,
                frequency: 1.68,
                verticalOffset: 0.50,
                bottomFade: 0.46,
                ridge: 0.24,
                driftDuration: 14,
                reverseDirection: true,
                strokeColor: theme.arcticFrostColor,
                strokeOpacity: 0.24 * scale,
                strokeWidth: 1.4
            )
            .frame(height: 200)

            ArcticRibbonOverlayView(
                color: theme.arcticFrostColor,
                opacity: 0.20 * scale,
                amplitude: 0.096 * scale,
                frequency: 2.28,
                verticalOffset: 0.57,
                bottomFade: 0.42,
                ridge: 0.30,
                driftDuration: 11,
                strokeColor: theme.arcticAuroraColor,
                strokeOpacity: 0.30 * scale,
                strokeWidth: 1.9
            )
            .frame(height: 200)

            LinearGradient(
                colors: [
                    theme.arcticFrostColor.opacity(0.22),
                    theme.arcticAuroraColor.opacity(0.12),
                    theme.arcticDeepColor.opacity(0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

struct ArcticDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            ArcticRibbonOverlayView(
                color: theme.arcticDeepColor,
                opacity: 0.07,
                amplitude: 0.024,
                frequency: 1.0,
                verticalOffset: 0.42,
                bottomFade: 0.56,
                ridge: 0.15,
                driftDuration: 16,
                strokeColor: theme.arcticFrostColor,
                strokeOpacity: 0.10,
                strokeWidth: 0.7
            )
            .frame(height: 150)

            ArcticRibbonOverlayView(
                color: theme.arcticAuroraColor,
                opacity: 0.12,
                amplitude: 0.045,
                frequency: 1.62,
                verticalOffset: 0.52,
                bottomFade: 0.52,
                ridge: 0.21,
                driftDuration: 13,
                reverseDirection: true,
                strokeColor: theme.arcticFrostColor,
                strokeOpacity: 0.18,
                strokeWidth: 1.1
            )
            .frame(height: 150)

            ArcticRibbonOverlayView(
                color: theme.arcticFrostColor,
                opacity: 0.16,
                amplitude: 0.06,
                frequency: 2.05,
                verticalOffset: 0.56,
                bottomFade: 0.50,
                ridge: 0.27,
                driftDuration: 11,
                strokeColor: theme.arcticAuroraColor,
                strokeOpacity: 0.22,
                strokeWidth: 1.3
            )
            .frame(height: 150)

            LinearGradient(
                colors: [theme.arcticFrostColor.opacity(DS.Opacity.light), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

struct ArcticSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            ArcticRibbonOverlayView(
                color: theme.arcticAuroraColor,
                opacity: 0.10,
                amplitude: 0.032,
                frequency: 1.52,
                verticalOffset: 0.50,
                bottomFade: 0.55,
                ridge: 0.20,
                driftDuration: 13,
                reverseDirection: true,
                strokeColor: theme.arcticFrostColor,
                strokeOpacity: 0.16,
                strokeWidth: 0.9
            )
            .frame(height: 120)

            ArcticRibbonOverlayView(
                color: theme.arcticFrostColor,
                opacity: 0.13,
                amplitude: 0.048,
                frequency: 1.92,
                verticalOffset: 0.54,
                bottomFade: 0.52,
                ridge: 0.24,
                driftDuration: 11,
                strokeColor: theme.arcticAuroraColor,
                strokeOpacity: 0.20,
                strokeWidth: 1.1
            )
            .frame(height: 120)

            LinearGradient(
                colors: [theme.arcticFrostColor.opacity(DS.Opacity.light), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("OceanTabWaveBackground") {
    OceanTabWaveBackground()
        .environment(\.appTheme, .oceanCool)
}

#Preview("Ocean Tab — All Presets") {
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
            OceanTabWaveBackground()
                .environment(\.wavePreset, preset)
                .environment(\.appTheme, .oceanCool)
                .overlay(alignment: .center) {
                    Text(name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .tabItem { Text(name) }
        }
    }
}

#Preview("Ocean Tab — Dark") {
    OceanTabWaveBackground()
        .environment(\.appTheme, .oceanCool)
        .preferredColorScheme(.dark)
}

#Preview("Arctic Tab — Dark") {
    ArcticTabWaveBackground()
        .environment(\.appTheme, .arcticDawn)
        .preferredColorScheme(.dark)
}
