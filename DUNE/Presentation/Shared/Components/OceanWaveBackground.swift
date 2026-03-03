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

// MARK: - Arctic Aurora Curtain Shape

/// Vertically flowing aurora veil used by Arctic Dawn backgrounds.
struct ArcticAuroraCurtainShape: Shape {
    let centerX: CGFloat
    let bandWidth: CGFloat
    let topInset: CGFloat
    let depth: CGFloat
    let sway: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private static let sampleCount = 88

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let center = rect.width * centerX
        let width = max(rect.width * bandWidth, 1)
        let startY = rect.height * topInset
        let height = rect.height * depth

        let count = Self.sampleCount
        var leftEdge: [CGPoint] = []
        var rightEdge: [CGPoint] = []
        leftEdge.reserveCapacity(count + 1)
        rightEdge.reserveCapacity(count + 1)

        for i in 0...count {
            let t = CGFloat(i) / CGFloat(count)
            let y = startY + height * t
            // Keep curtains mostly vertical so layers read as parallel aurora drapes.
            let drift = sin(t * 2.4 + phase + centerX * 0.6) * width * sway
            let twist = cos(t * 1.2 + phase * 0.35) * width * 0.03
            let taper = max(1 - t * 0.14, 0.7)
            let halfWidth = width * 0.5 * taper
            let x = center + drift + twist

            leftEdge.append(CGPoint(x: x - halfWidth, y: y))
            rightEdge.append(CGPoint(x: x + halfWidth, y: y))
        }

        var path = Path()
        guard let first = leftEdge.first else { return path }

        path.move(to: first)
        for point in leftEdge.dropFirst() {
            path.addLine(to: point)
        }
        for point in rightEdge.reversed() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

private struct ArcticAuroraCurtainSpec {
    let centerX: CGFloat
    let bandWidth: CGFloat
    let topInset: CGFloat
    let depth: CGFloat
    let sway: CGFloat
    let tilt: Double
}

enum ArcticAuroraQualityMode: Sendable {
    case normal
    case conserve
}

enum ArcticAuroraLOD {
    static func qualityMode(isLowPowerModeEnabled: Bool, reduceMotion: Bool) -> ArcticAuroraQualityMode {
        if reduceMotion || isLowPowerModeEnabled {
            return .conserve
        }
        return .normal
    }

    static func scaledCount(
        baseCount: Int,
        mode: ArcticAuroraQualityMode,
        normalScale: Double = 1.0,
        conserveScale: Double,
        minimum: Int = 1
    ) -> Int {
        guard baseCount > 0 else { return 0 }
        let rawScale = (mode == .normal) ? normalScale : conserveScale
        let scaled = Int((Double(baseCount) * rawScale).rounded(.down))
        return max(minimum, scaled)
    }
}

struct ArcticAuroraCurtainOverlayView: View {
    var primaryColor: Color
    var secondaryColor: Color
    var opacity: Double = 0.16
    var bottomFade: CGFloat = 0.5
    var driftDuration: Double = 14
    var reverseDirection: Bool = false
    var blurRadius: CGFloat = 1.6
    var highlights: Bool = true
    var saturationBoost: Double = 1.16
    var hueShift: Double = 0
    var filamentLines: Int = 0
    var filamentOpacity: Double = 0.0
    var filamentWidth: CGFloat = 0.36
    var filamentSpread: CGFloat = 0.010
    var qualityMode: ArcticAuroraQualityMode = .normal

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let curtainSpecs: [ArcticAuroraCurtainSpec] = [
        .init(centerX: 0.12, bandWidth: 0.14, topInset: -0.07, depth: 0.98, sway: 0.08, tilt: -2),
        .init(centerX: 0.26, bandWidth: 0.15, topInset: -0.06, depth: 0.97, sway: 0.07, tilt: -1),
        .init(centerX: 0.40, bandWidth: 0.14, topInset: -0.07, depth: 0.99, sway: 0.09, tilt: 0),
        .init(centerX: 0.54, bandWidth: 0.15, topInset: -0.06, depth: 0.97, sway: 0.07, tilt: 1),
        .init(centerX: 0.68, bandWidth: 0.14, topInset: -0.08, depth: 0.98, sway: 0.08, tilt: 2),
        .init(centerX: 0.82, bandWidth: 0.13, topInset: -0.06, depth: 0.95, sway: 0.06, tilt: 1),
    ]

    private var targetPhase: CGFloat {
        (reverseDirection ? -1 : 1) * 2 * .pi
    }

    private var activeCurtainSpecs: ArraySlice<ArcticAuroraCurtainSpec> {
        let count = ArcticAuroraLOD.scaledCount(
            baseCount: Self.curtainSpecs.count,
            mode: qualityMode,
            conserveScale: 0.72
        )
        return Self.curtainSpecs.prefix(count)
    }

    private var activeFilamentLines: Int {
        ArcticAuroraLOD.scaledCount(
            baseCount: filamentLines,
            mode: qualityMode,
            conserveScale: 0.58
        )
    }

    private var blurScale: CGFloat {
        qualityMode == .normal ? 1.0 : 0.82
    }

    private var highlightOpacityScale: Double {
        qualityMode == .normal ? 1.0 : 0.78
    }

    private var filamentOpacityScale: Double {
        qualityMode == .normal ? 1.0 : 0.74
    }

    var body: some View {
        let curtainSpecs = activeCurtainSpecs
        let filamentLineCount = activeFilamentLines

        ZStack {
            ForEach(curtainSpecs.indices, id: \.self) { idx in
                let spec = curtainSpecs[idx]
                let localPhase = phase + CGFloat(idx) * 0.26
                let bandOpacity = opacity * (0.82 + Double((idx + 1) % 3) * 0.12)
                let shape = ArcticAuroraCurtainShape(
                    centerX: spec.centerX,
                    bandWidth: spec.bandWidth,
                    topInset: spec.topInset,
                    depth: spec.depth,
                    sway: spec.sway,
                    phase: localPhase
                )

                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                primaryColor.opacity(bandOpacity * 0.95),
                                secondaryColor.opacity(bandOpacity),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .hueRotation(.degrees(hueShift))
                    .saturation(saturationBoost)
                    .rotationEffect(.degrees(spec.tilt))
                    .blur(radius: (blurRadius + CGFloat(idx % 2) * 0.45) * blurScale)
                    .blendMode(.screen)
                    .bottomFadeMask(bottomFade)

                if highlights {
                    shape
                        .stroke(
                            secondaryColor.opacity(bandOpacity * 0.28 * highlightOpacityScale),
                            style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
                        )
                        .hueRotation(.degrees(hueShift * 0.6))
                        .saturation(saturationBoost + 0.06)
                        .rotationEffect(.degrees(spec.tilt))
                        .blur(radius: 0.9 * blurScale)
                        .blendMode(.plusLighter)
                        .bottomFadeMask(bottomFade)
                }

                if filamentLineCount > 0, filamentOpacity > 0 {
                    ForEach(0..<filamentLineCount, id: \.self) { strand in
                        let center = CGFloat(filamentLineCount - 1) / 2
                        let offset = CGFloat(strand) - center
                        let strandShape = ArcticAuroraCurtainShape(
                            centerX: spec.centerX + offset * filamentSpread,
                            bandWidth: spec.bandWidth * max(0.08, 0.20 - abs(offset) * 0.02),
                            topInset: spec.topInset,
                            depth: spec.depth * (0.96 + CGFloat(strand % 2) * 0.02),
                            sway: max(spec.sway * 0.42, 0.02),
                            phase: localPhase + offset * 0.18
                        )

                        strandShape
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        primaryColor.opacity(bandOpacity * filamentOpacity * filamentOpacityScale * 0.48),
                                        secondaryColor.opacity(bandOpacity * filamentOpacity * filamentOpacityScale),
                                        Color.white.opacity(bandOpacity * filamentOpacity * filamentOpacityScale * 0.34),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                style: StrokeStyle(
                                    lineWidth: filamentWidth + (strand % 2 == 0 ? 0 : 0.10),
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .hueRotation(.degrees(hueShift * 0.5 + Double(offset) * 0.7))
                            .saturation(saturationBoost + 0.08)
                            .rotationEffect(.degrees(spec.tilt))
                            .blur(radius: (0.32 + CGFloat(strand % 3) * 0.10) * blurScale)
                            .blendMode(.plusLighter)
                            .bottomFadeMask(bottomFade)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion, driftDuration > 0 else { return }
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = targetPhase
            }
        }
    }
}

private struct ArcticAuroraSkyGlow: View {
    var primaryColor: Color
    var secondaryColor: Color
    var opacity: Double = 0.22

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [primaryColor.opacity(opacity), .clear],
                center: UnitPoint(x: 0.22, y: 0.02),
                startRadius: 4,
                endRadius: 220
            )

            RadialGradient(
                colors: [secondaryColor.opacity(opacity * 0.88), .clear],
                center: UnitPoint(x: 0.76, y: 0.10),
                startRadius: 4,
                endRadius: 190
            )
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

private struct ArcticAuroraEdgeGlowShape: Shape {
    let crestY: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private static let sampleCount = 84

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let centerY = rect.height * crestY
        let amp = rect.height * amplitude

        var path = Path()
        for i in 0...Self.sampleCount {
            let t = CGFloat(i) / CGFloat(Self.sampleCount)
            let x = rect.width * t
            let y = centerY
                + sin(t * frequency * 2 * .pi + phase) * amp
                + cos(t * (frequency * 0.57) * 2 * .pi + phase * 0.7) * amp * 0.34

            if i == 0 {
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

private struct ArcticAuroraEdgeTextureOverlayView: View {
    var primaryColor: Color
    var secondaryColor: Color
    var highlightColor: Color
    var opacity: Double = 0.20
    var driftDuration: Double = 16
    var qualityMode: ArcticAuroraQualityMode = .normal

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sparkleSeeds: [Double] = [
        0.04, 0.09, 0.13, 0.18, 0.24, 0.31, 0.37, 0.42,
        0.49, 0.55, 0.61, 0.66, 0.73, 0.79, 0.84, 0.90, 0.95
    ]

    private var targetPhase: CGFloat { 2 * .pi }
    private var blurScale: CGFloat { qualityMode == .normal ? 1.0 : 0.84 }
    private var sparkleOpacityScale: Double { qualityMode == .normal ? 1.0 : 0.76 }
    private var activeSparkleSeeds: ArraySlice<Double> {
        let count = ArcticAuroraLOD.scaledCount(
            baseCount: Self.sparkleSeeds.count,
            mode: qualityMode,
            conserveScale: 0.64
        )
        return Self.sparkleSeeds.prefix(count)
    }

    var body: some View {
        GeometryReader { proxy in
            let sparkleSeeds = activeSparkleSeeds

            ZStack {
                ArcticAuroraEdgeGlowShape(
                    crestY: 0.34,
                    amplitude: 0.09,
                    frequency: 1.55,
                    phase: phase
                )
                .fill(
                    LinearGradient(
                        colors: [
                            highlightColor.opacity(opacity * 0.95),
                            primaryColor.opacity(opacity * 0.72),
                            secondaryColor.opacity(opacity * 0.34),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 2.6 * blurScale)
                .blendMode(.screen)

                ArcticAuroraEdgeGlowShape(
                    crestY: 0.39,
                    amplitude: 0.12,
                    frequency: 2.08,
                    phase: -phase * 0.78 + 0.9
                )
                .fill(
                    LinearGradient(
                        colors: [
                            primaryColor.opacity(opacity * 0.58),
                            secondaryColor.opacity(opacity * 0.44),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 3.2 * blurScale)
                .blendMode(.screen)

                ForEach(sparkleSeeds.indices, id: \.self) { idx in
                    let seed = sparkleSeeds[idx]
                    let x = proxy.size.width * CGFloat(seed)
                    let yBase = proxy.size.height * (0.31 + 0.09 * abs(sin(seed * 14.0)))
                    let yDrift = sin(phase * 0.9 + CGFloat(idx) * 0.52) * proxy.size.height * 0.02
                    let size = 1.0 + CGFloat(idx % 3) * 0.7
                    Circle()
                        .fill(highlightColor.opacity(opacity * sparkleOpacityScale * (0.32 + Double(idx % 4) * 0.08)))
                        .frame(width: size, height: size)
                        .position(x: x, y: yBase + yDrift)
                        .blur(radius: (idx.isMultiple(of: 2) ? 0.2 : 0.5) * blurScale)
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion, driftDuration > 0 else { return }
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = targetPhase
            }
        }
    }
}

private struct ArcticAuroraMicroStrandSpec {
    let x: CGFloat
    let width: CGFloat
    let topInset: CGFloat
    let depth: CGFloat
    let tilt: Double
    let intensity: Double
    let colorOffset: Int
}

private struct ArcticAuroraMicroDetailOverlayView: View {
    var opacity: Double = 0.16
    var driftDuration: Double = 18
    var leftClusterBoost: Double = 1.25
    var qualityMode: ArcticAuroraQualityMode = .normal

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let strandSpecs: [ArcticAuroraMicroStrandSpec] = [
        .init(x: 0.03, width: 0.0036, topInset: -0.05, depth: 0.98, tilt: -1.5, intensity: 1.00, colorOffset: 0),
        .init(x: 0.06, width: 0.0032, topInset: -0.04, depth: 0.94, tilt: -1.2, intensity: 0.94, colorOffset: 1),
        .init(x: 0.09, width: 0.0038, topInset: -0.06, depth: 0.99, tilt: -1.0, intensity: 1.05, colorOffset: 2),
        .init(x: 0.12, width: 0.0034, topInset: -0.03, depth: 0.92, tilt: -0.6, intensity: 0.92, colorOffset: 3),
        .init(x: 0.15, width: 0.0030, topInset: -0.03, depth: 0.88, tilt: -0.4, intensity: 0.90, colorOffset: 4),
        .init(x: 0.18, width: 0.0037, topInset: -0.05, depth: 0.96, tilt: -0.2, intensity: 0.98, colorOffset: 5),
        .init(x: 0.21, width: 0.0033, topInset: -0.04, depth: 0.90, tilt: 0.2, intensity: 0.88, colorOffset: 2),
        .init(x: 0.24, width: 0.0036, topInset: -0.05, depth: 0.95, tilt: 0.3, intensity: 0.95, colorOffset: 1),
        .init(x: 0.27, width: 0.0030, topInset: -0.03, depth: 0.89, tilt: 0.5, intensity: 0.86, colorOffset: 0),
        .init(x: 0.31, width: 0.0027, topInset: -0.03, depth: 0.85, tilt: 0.7, intensity: 0.78, colorOffset: 3),
        .init(x: 0.36, width: 0.0029, topInset: -0.02, depth: 0.82, tilt: 0.8, intensity: 0.75, colorOffset: 4),
        .init(x: 0.41, width: 0.0030, topInset: -0.03, depth: 0.86, tilt: 0.9, intensity: 0.77, colorOffset: 5),
        .init(x: 0.47, width: 0.0028, topInset: -0.02, depth: 0.80, tilt: 0.9, intensity: 0.72, colorOffset: 1),
        .init(x: 0.53, width: 0.0027, topInset: -0.02, depth: 0.78, tilt: 0.8, intensity: 0.68, colorOffset: 2),
        .init(x: 0.59, width: 0.0028, topInset: -0.02, depth: 0.82, tilt: 0.6, intensity: 0.70, colorOffset: 3),
        .init(x: 0.65, width: 0.0029, topInset: -0.03, depth: 0.84, tilt: 0.4, intensity: 0.72, colorOffset: 0),
        .init(x: 0.71, width: 0.0027, topInset: -0.02, depth: 0.79, tilt: 0.2, intensity: 0.66, colorOffset: 5),
        .init(x: 0.77, width: 0.0028, topInset: -0.03, depth: 0.83, tilt: 0.0, intensity: 0.68, colorOffset: 4),
        .init(x: 0.83, width: 0.0029, topInset: -0.03, depth: 0.81, tilt: -0.2, intensity: 0.70, colorOffset: 1),
        .init(x: 0.89, width: 0.0026, topInset: -0.02, depth: 0.76, tilt: -0.3, intensity: 0.62, colorOffset: 2),
        .init(x: 0.94, width: 0.0025, topInset: -0.02, depth: 0.74, tilt: -0.4, intensity: 0.58, colorOffset: 3),
    ]

    private static let sparkleSeeds: [Double] = [
        0.02, 0.035, 0.05, 0.065, 0.08, 0.095, 0.11, 0.13, 0.15, 0.17, 0.19, 0.21, 0.23, 0.255, 0.28,
        0.31, 0.35, 0.39, 0.43, 0.47, 0.52, 0.56, 0.60, 0.64, 0.69, 0.73, 0.77, 0.82, 0.87, 0.92, 0.96
    ]
    private static let crestSeeds: [Double] = [
        0.03, 0.06, 0.09, 0.12, 0.15, 0.18, 0.21, 0.24, 0.27, 0.30,
        0.34, 0.38, 0.42, 0.46, 0.50, 0.54, 0.58, 0.62, 0.66, 0.70,
        0.74, 0.78, 0.82, 0.86, 0.90, 0.94, 0.97
    ]
    private static let palette: [Color] = [
        ArcticAuroraPalette.neonMint,
        ArcticAuroraPalette.emerald,
        ArcticAuroraPalette.lime,
        ArcticAuroraPalette.cyan,
        ArcticAuroraPalette.violet,
        ArcticAuroraPalette.magenta,
        ArcticAuroraPalette.pearl
    ]

    private var targetPhase: CGFloat { 2 * .pi }
    private var activeStrandSpecs: ArraySlice<ArcticAuroraMicroStrandSpec> {
        let count = ArcticAuroraLOD.scaledCount(
            baseCount: Self.strandSpecs.count,
            mode: qualityMode,
            conserveScale: 0.62
        )
        return Self.strandSpecs.prefix(count)
    }

    private var activeCrestSeeds: ArraySlice<Double> {
        let count = ArcticAuroraLOD.scaledCount(
            baseCount: Self.crestSeeds.count,
            mode: qualityMode,
            conserveScale: 0.66
        )
        return Self.crestSeeds.prefix(count)
    }

    private var activeSparkleSeeds: ArraySlice<Double> {
        let count = ArcticAuroraLOD.scaledCount(
            baseCount: Self.sparkleSeeds.count,
            mode: qualityMode,
            conserveScale: 0.58
        )
        return Self.sparkleSeeds.prefix(count)
    }

    private var blurScale: CGFloat { qualityMode == .normal ? 1.0 : 0.82 }
    private var sparkleOpacityScale: Double { qualityMode == .normal ? 1.0 : 0.72 }
    private var effectiveLeftClusterBoost: Double {
        guard qualityMode == .conserve else { return leftClusterBoost }
        return max(1.0, leftClusterBoost * 0.88)
    }

    var body: some View {
        GeometryReader { proxy in
            let palette = Self.palette
            let strandSpecs = activeStrandSpecs
            let crestSeeds = activeCrestSeeds
            let sparkleSeeds = activeSparkleSeeds

            ZStack {
                ForEach(strandSpecs.indices, id: \.self) { idx in
                    let spec = strandSpecs[idx]
                    let isLeftCluster = spec.x < 0.30
                    let clusterScale = isLeftCluster ? effectiveLeftClusterBoost : 1.0
                    let localOpacity = opacity * spec.intensity * clusterScale
                    let xDrift = sin(phase * 0.68 + CGFloat(idx) * 0.57) * proxy.size.width * (isLeftCluster ? 0.007 : 0.004)
                    let y = proxy.size.height * spec.topInset
                    let h = proxy.size.height * spec.depth
                    let topColor = palette[(idx + spec.colorOffset) % palette.count]
                    let midColor = palette[(idx + spec.colorOffset + 2) % palette.count]

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    topColor.opacity(localOpacity * 0.74),
                                    midColor.opacity(localOpacity * 0.66),
                                    Color.white.opacity(localOpacity * 0.22),
                                    .clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(proxy.size.width * spec.width, 0.75), height: h)
                        .rotationEffect(.degrees(spec.tilt))
                        .position(x: proxy.size.width * spec.x + xDrift, y: y + h / 2)
                        .blur(radius: (isLeftCluster ? 0.22 : 0.36) * blurScale)
                        .blendMode(.screen)

                    Capsule(style: .continuous)
                        .stroke(
                            Color.white.opacity(localOpacity * 0.28),
                            style: StrokeStyle(lineWidth: 0.22, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: max(proxy.size.width * spec.width * 0.48, 0.38), height: h * 0.95)
                        .rotationEffect(.degrees(spec.tilt * 0.8))
                        .position(x: proxy.size.width * spec.x + xDrift * 0.9, y: y + h / 2)
                        .blur(radius: 0.12 * blurScale)
                        .blendMode(.plusLighter)
                }

                ForEach(crestSeeds.indices, id: \.self) { idx in
                    let seed = crestSeeds[idx]
                    let isLeftCluster = seed < 0.30
                    let clusterScale = isLeftCluster ? effectiveLeftClusterBoost : 1.0
                    let x = proxy.size.width * CGFloat(seed)
                        + sin(phase * 0.55 + CGFloat(idx) * 0.44) * proxy.size.width * 0.004
                    let crest = proxy.size.height
                        * (0.56 + 0.08 * sin(seed * 8.8 + Double(phase) * 0.24))
                    let spikeHeight = proxy.size.height
                        * (0.20 + 0.24 * abs(sin(seed * 17.6 + Double(phase) * 0.66))) * 1.2
                    let spikeWidth = 1.0 + CGFloat(idx % 3) * 0.28
                    let lowerGlow = 0.62 + 0.38 * abs(cos(seed * 13.2 + Double(phase) * 0.48))

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ArcticAuroraPalette.violet.opacity(opacity * 0.56 * clusterScale),
                                    ArcticAuroraPalette.magenta.opacity(opacity * 0.44 * clusterScale),
                                    ArcticAuroraPalette.neonMint.opacity(opacity * 0.38 * lowerGlow * clusterScale),
                                    .clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: spikeWidth, height: spikeHeight)
                        .position(x: x, y: crest - spikeHeight * 0.42)
                        .blur(radius: (isLeftCluster ? 0.24 : 0.32) * blurScale)
                        .blendMode(.screen)

                    Circle()
                        .fill(ArcticAuroraPalette.lime.opacity(opacity * 0.22 * lowerGlow * clusterScale))
                        .frame(width: 1.0 + CGFloat(idx % 2) * 0.4, height: 1.0 + CGFloat(idx % 2) * 0.4)
                        .position(x: x, y: crest + spikeHeight * 0.02)
                        .blur(radius: 0.18 * blurScale)
                        .blendMode(.plusLighter)
                }

                ForEach(sparkleSeeds.indices, id: \.self) { idx in
                    let seed = sparkleSeeds[idx]
                    let isLeftCluster = seed < 0.30
                    let clusterScale = isLeftCluster ? effectiveLeftClusterBoost : 1.0
                    let x = proxy.size.width * CGFloat(seed)
                        + sin(phase * 0.82 + CGFloat(idx) * 0.41) * proxy.size.width * 0.0032
                    let y = proxy.size.height * (0.12 + 0.76 * abs(cos(seed * 9.7 + Double(phase) * 0.22)))
                    let size = 0.72 + CGFloat(idx % 4) * 0.34
                    let color = palette[(idx * 2 + 1) % palette.count]

                    Circle()
                        .fill(color.opacity(opacity * sparkleOpacityScale * clusterScale * (0.18 + Double(idx % 3) * 0.08)))
                        .frame(width: size, height: size)
                        .position(x: x, y: y)
                        .blur(radius: (idx.isMultiple(of: 2) ? 0.08 : 0.24) * blurScale)
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion, driftDuration > 0 else { return }
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = targetPhase
            }
        }
    }
}

private enum ArcticAuroraPalette {
    static let cyan = Color(red: 0.27, green: 0.90, blue: 0.92)
    static let aqua = Color(red: 0.36, green: 0.88, blue: 0.95)
    static let neonMint = Color(red: 0.52, green: 0.97, blue: 0.80)
    static let emerald = Color(red: 0.30, green: 0.91, blue: 0.66)
    static let lime = Color(red: 0.73, green: 0.98, blue: 0.52)
    static let teal = Color(red: 0.39, green: 0.83, blue: 0.74)
    static let amethyst = Color(red: 0.59, green: 0.45, blue: 0.88)
    static let violet = Color(red: 0.68, green: 0.44, blue: 0.94)
    static let ultraviolet = Color(red: 0.53, green: 0.34, blue: 0.88)
    static let magenta = Color(red: 0.80, green: 0.39, blue: 0.83)
    static let rose = Color(red: 0.77, green: 0.49, blue: 0.74)
    static let champagne = Color(red: 0.95, green: 0.84, blue: 0.67)
    static let pearl = Color(red: 0.96, green: 0.93, blue: 0.84)
    static let deepNavy = Color(red: 0.06, green: 0.10, blue: 0.24)
}

// MARK: - Arctic Dawn Backgrounds

struct ArcticTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.15
        case .today:    1.0
        case .wellness: 0.82
        case .life:     0.68
        }
    }

    private var qualityMode: ArcticAuroraQualityMode {
        ArcticAuroraLOD.qualityMode(
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            reduceMotion: reduceMotion
        )
    }

    var body: some View {
        let scale = intensityScale
        let mode = qualityMode

        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    ArcticAuroraPalette.deepNavy.opacity(0.92),
                    ArcticAuroraPalette.ultraviolet.opacity(0.55 * scale),
                    theme.arcticDeepColor.opacity(0.62 * scale),
                    theme.arcticDeepColor.opacity(0.26),
                    theme.arcticFrostColor.opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Pre-change Arctic sea silhouette (ribbon-wave base)
            ArcticRibbonOverlayView(
                color: theme.arcticDeepColor,
                opacity: 0.14 * scale,
                amplitude: 0.035 * scale,
                frequency: 0.98,
                verticalOffset: 0.40,
                bottomFade: 0.42,
                ridge: 0.17,
                driftDuration: 18,
                strokeColor: theme.arcticFrostColor,
                strokeOpacity: 0.14 * scale,
                strokeWidth: 0.9
            )
            .frame(height: 280)

            ArcticRibbonOverlayView(
                color: theme.arcticAuroraColor,
                opacity: 0.22 * scale,
                amplitude: 0.072 * scale,
                frequency: 1.66,
                verticalOffset: 0.50,
                bottomFade: 0.34,
                ridge: 0.24,
                driftDuration: 14,
                reverseDirection: true,
                strokeColor: ArcticAuroraPalette.neonMint,
                strokeOpacity: 0.26 * scale,
                strokeWidth: 1.4
            )
            .frame(height: 280)

            ArcticRibbonOverlayView(
                color: theme.arcticFrostColor,
                opacity: 0.26 * scale,
                amplitude: 0.096 * scale,
                frequency: 2.24,
                verticalOffset: 0.57,
                bottomFade: 0.30,
                ridge: 0.30,
                driftDuration: 11,
                strokeColor: ArcticAuroraPalette.violet,
                strokeOpacity: 0.30 * scale,
                strokeWidth: 1.9
            )
            .frame(height: 280)

            ArcticAuroraSkyGlow(
                primaryColor: ArcticAuroraPalette.neonMint,
                secondaryColor: ArcticAuroraPalette.violet,
                opacity: 0.34 * scale
            )

            ArcticAuroraSkyGlow(
                primaryColor: ArcticAuroraPalette.magenta,
                secondaryColor: ArcticAuroraPalette.champagne,
                opacity: 0.20 * scale
            )

            ArcticAuroraCurtainOverlayView(
                primaryColor: ArcticAuroraPalette.neonMint,
                secondaryColor: ArcticAuroraPalette.emerald,
                opacity: 0.34 * scale,
                bottomFade: 0.28,
                driftDuration: 14,
                reverseDirection: true,
                blurRadius: 1.9,
                highlights: true,
                saturationBoost: 1.26,
                hueShift: -4,
                filamentLines: 11,
                filamentOpacity: 0.26,
                filamentWidth: 0.32,
                filamentSpread: 0.008,
                qualityMode: mode
            )
            .frame(height: 300)

            ArcticAuroraCurtainOverlayView(
                primaryColor: ArcticAuroraPalette.violet,
                secondaryColor: ArcticAuroraPalette.magenta,
                opacity: 0.27 * scale,
                bottomFade: 0.26,
                driftDuration: 18,
                reverseDirection: false,
                blurRadius: 1.6,
                highlights: true,
                saturationBoost: 1.21,
                hueShift: 4,
                filamentLines: 9,
                filamentOpacity: 0.23,
                filamentWidth: 0.30,
                filamentSpread: 0.007,
                qualityMode: mode
            )
            .frame(height: 300)

            ArcticAuroraCurtainOverlayView(
                primaryColor: ArcticAuroraPalette.aqua,
                secondaryColor: ArcticAuroraPalette.amethyst,
                opacity: 0.19 * scale,
                bottomFade: 0.30,
                driftDuration: 20,
                reverseDirection: true,
                blurRadius: 2.2,
                highlights: false,
                saturationBoost: 1.18,
                hueShift: 1,
                filamentLines: 7,
                filamentOpacity: 0.16,
                filamentWidth: 0.28,
                filamentSpread: 0.006,
                qualityMode: mode
            )
            .frame(height: 320)

            ArcticAuroraCurtainOverlayView(
                primaryColor: ArcticAuroraPalette.rose,
                secondaryColor: ArcticAuroraPalette.champagne,
                opacity: 0.12 * scale,
                bottomFade: 0.31,
                driftDuration: 24,
                reverseDirection: false,
                blurRadius: 2.9,
                highlights: false,
                saturationBoost: 1.13,
                hueShift: -2,
                filamentLines: 5,
                filamentOpacity: 0.12,
                filamentWidth: 0.26,
                filamentSpread: 0.006,
                qualityMode: mode
            )
            .frame(height: 330)

            ArcticAuroraMicroDetailOverlayView(
                opacity: 0.23 * scale,
                driftDuration: 18,
                leftClusterBoost: 1.55,
                qualityMode: mode
            )
            .frame(height: 332)
            .blendMode(.screen)

            ArcticAuroraEdgeTextureOverlayView(
                primaryColor: ArcticAuroraPalette.emerald,
                secondaryColor: ArcticAuroraPalette.neonMint,
                highlightColor: ArcticAuroraPalette.lime,
                opacity: 0.22 * scale,
                driftDuration: 16,
                qualityMode: mode
            )
            .frame(height: 118)
            .offset(y: 132)
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    .clear,
                    ArcticAuroraPalette.pearl.opacity(0.24 * scale),
                    ArcticAuroraPalette.lime.opacity(0.22 * scale),
                    ArcticAuroraPalette.cyan.opacity(0.17 * scale),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 104)
            .blur(radius: 9)
            .offset(y: 128)
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    theme.arcticFrostColor.opacity(0.21 * scale),
                    ArcticAuroraPalette.neonMint.opacity(0.16 * scale),
                    ArcticAuroraPalette.violet.opacity(0.15 * scale),
                    ArcticAuroraPalette.magenta.opacity(0.13 * scale),
                    ArcticAuroraPalette.champagne.opacity(0.10 * scale),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

struct ArcticDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var qualityMode: ArcticAuroraQualityMode {
        ArcticAuroraLOD.qualityMode(
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            reduceMotion: reduceMotion
        )
    }

    var body: some View {
        let mode = qualityMode

        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    ArcticAuroraPalette.deepNavy.opacity(0.84),
                    ArcticAuroraPalette.ultraviolet.opacity(0.34),
                    theme.arcticDeepColor.opacity(0.44),
                    theme.arcticDeepColor.opacity(0.16),
                    theme.arcticFrostColor.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ArcticRibbonOverlayView(
                color: theme.arcticDeepColor,
                opacity: 0.11,
                amplitude: 0.025,
                frequency: 1.02,
                verticalOffset: 0.42,
                bottomFade: 0.42,
                ridge: 0.15,
                driftDuration: 16,
                strokeColor: theme.arcticFrostColor,
                strokeOpacity: 0.10,
                strokeWidth: 0.7
            )
            .frame(height: 200)

            ArcticRibbonOverlayView(
                color: theme.arcticAuroraColor,
                opacity: 0.15,
                amplitude: 0.048,
                frequency: 1.62,
                verticalOffset: 0.52,
                bottomFade: 0.40,
                ridge: 0.21,
                driftDuration: 13,
                reverseDirection: true,
                strokeColor: ArcticAuroraPalette.neonMint,
                strokeOpacity: 0.20,
                strokeWidth: 1.1
            )
            .frame(height: 200)

            ArcticRibbonOverlayView(
                color: theme.arcticFrostColor,
                opacity: 0.18,
                amplitude: 0.064,
                frequency: 2.02,
                verticalOffset: 0.56,
                bottomFade: 0.36,
                ridge: 0.27,
                driftDuration: 11,
                strokeColor: ArcticAuroraPalette.violet,
                strokeOpacity: 0.22,
                strokeWidth: 1.3
            )
            .frame(height: 200)

            ArcticAuroraSkyGlow(
                primaryColor: ArcticAuroraPalette.neonMint,
                secondaryColor: ArcticAuroraPalette.violet,
                opacity: 0.24
            )

            ArcticAuroraSkyGlow(
                primaryColor: ArcticAuroraPalette.magenta,
                secondaryColor: ArcticAuroraPalette.champagne,
                opacity: 0.13
            )

            ArcticAuroraCurtainOverlayView(
                primaryColor: ArcticAuroraPalette.neonMint,
                secondaryColor: ArcticAuroraPalette.emerald,
                opacity: 0.20,
                bottomFade: 0.32,
                driftDuration: 13,
                reverseDirection: true,
                blurRadius: 1.4,
                saturationBoost: 1.2,
                hueShift: -3,
                filamentLines: 8,
                filamentOpacity: 0.18,
                filamentWidth: 0.27,
                filamentSpread: 0.007,
                qualityMode: mode
            )
            .frame(height: 210)

            ArcticAuroraCurtainOverlayView(
                primaryColor: ArcticAuroraPalette.violet,
                secondaryColor: ArcticAuroraPalette.magenta,
                opacity: 0.14,
                bottomFade: 0.31,
                driftDuration: 17,
                blurRadius: 1.3,
                highlights: true,
                saturationBoost: 1.15,
                hueShift: 3,
                filamentLines: 7,
                filamentOpacity: 0.16,
                filamentWidth: 0.26,
                filamentSpread: 0.006,
                qualityMode: mode
            )
            .frame(height: 210)

            ArcticAuroraCurtainOverlayView(
                primaryColor: ArcticAuroraPalette.aqua,
                secondaryColor: ArcticAuroraPalette.amethyst,
                opacity: 0.10,
                bottomFade: 0.35,
                driftDuration: 19,
                reverseDirection: true,
                blurRadius: 1.8,
                highlights: false,
                saturationBoost: 1.12,
                hueShift: 1,
                filamentLines: 5,
                filamentOpacity: 0.11,
                filamentWidth: 0.24,
                filamentSpread: 0.006,
                qualityMode: mode
            )
            .frame(height: 220)

            ArcticAuroraMicroDetailOverlayView(
                opacity: 0.15,
                driftDuration: 17,
                leftClusterBoost: 1.45,
                qualityMode: mode
            )
            .frame(height: 224)
            .blendMode(.screen)

            ArcticAuroraEdgeTextureOverlayView(
                primaryColor: ArcticAuroraPalette.emerald,
                secondaryColor: ArcticAuroraPalette.neonMint,
                highlightColor: ArcticAuroraPalette.lime,
                opacity: 0.16,
                driftDuration: 14,
                qualityMode: mode
            )
            .frame(height: 86)
            .offset(y: 96)
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    .clear,
                    ArcticAuroraPalette.pearl.opacity(0.16),
                    ArcticAuroraPalette.lime.opacity(0.14),
                    ArcticAuroraPalette.cyan.opacity(0.10),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 72)
            .blur(radius: 6)
            .offset(y: 84)
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    theme.arcticFrostColor.opacity(0.17),
                    ArcticAuroraPalette.neonMint.opacity(0.11),
                    ArcticAuroraPalette.violet.opacity(0.10),
                    ArcticAuroraPalette.magenta.opacity(0.08),
                    ArcticAuroraPalette.champagne.opacity(0.06),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

struct ArcticSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var qualityMode: ArcticAuroraQualityMode {
        ArcticAuroraLOD.qualityMode(
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            reduceMotion: reduceMotion
        )
    }

    var body: some View {
        let mode = qualityMode

        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    ArcticAuroraPalette.deepNavy.opacity(0.76),
                    ArcticAuroraPalette.ultraviolet.opacity(0.27),
                    theme.arcticDeepColor.opacity(0.34),
                    theme.arcticDeepColor.opacity(0.12),
                    theme.arcticFrostColor.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ArcticRibbonOverlayView(
                color: theme.arcticAuroraColor,
                opacity: 0.12,
                amplitude: 0.034,
                frequency: 1.54,
                verticalOffset: 0.50,
                bottomFade: 0.44,
                ridge: 0.20,
                driftDuration: 13,
                reverseDirection: true,
                strokeColor: ArcticAuroraPalette.neonMint,
                strokeOpacity: 0.16,
                strokeWidth: 0.9
            )
            .frame(height: 150)

            ArcticRibbonOverlayView(
                color: theme.arcticFrostColor,
                opacity: 0.14,
                amplitude: 0.05,
                frequency: 1.92,
                verticalOffset: 0.54,
                bottomFade: 0.40,
                ridge: 0.24,
                driftDuration: 11,
                strokeColor: ArcticAuroraPalette.violet,
                strokeOpacity: 0.18,
                strokeWidth: 1.1
            )
            .frame(height: 150)

            ArcticAuroraSkyGlow(
                primaryColor: ArcticAuroraPalette.neonMint,
                secondaryColor: ArcticAuroraPalette.violet,
                opacity: 0.19
            )

            ArcticAuroraSkyGlow(
                primaryColor: ArcticAuroraPalette.magenta,
                secondaryColor: ArcticAuroraPalette.champagne,
                opacity: 0.10
            )

            ArcticAuroraCurtainOverlayView(
                primaryColor: ArcticAuroraPalette.neonMint,
                secondaryColor: ArcticAuroraPalette.emerald,
                opacity: 0.14,
                bottomFade: 0.35,
                driftDuration: 12,
                reverseDirection: true,
                blurRadius: 1.2,
                highlights: false,
                saturationBoost: 1.15,
                hueShift: -2,
                filamentLines: 6,
                filamentOpacity: 0.14,
                filamentWidth: 0.22,
                filamentSpread: 0.006,
                qualityMode: mode
            )
            .frame(height: 150)

            ArcticAuroraCurtainOverlayView(
                primaryColor: ArcticAuroraPalette.violet,
                secondaryColor: ArcticAuroraPalette.magenta,
                opacity: 0.09,
                bottomFade: 0.32,
                driftDuration: 16,
                blurRadius: 1.1,
                highlights: false,
                saturationBoost: 1.12,
                hueShift: 2,
                filamentLines: 5,
                filamentOpacity: 0.11,
                filamentWidth: 0.21,
                filamentSpread: 0.005,
                qualityMode: mode
            )
            .frame(height: 150)

            ArcticAuroraMicroDetailOverlayView(
                opacity: 0.11,
                driftDuration: 16,
                leftClusterBoost: 1.32,
                qualityMode: mode
            )
            .frame(height: 154)
            .blendMode(.screen)

            ArcticAuroraEdgeTextureOverlayView(
                primaryColor: ArcticAuroraPalette.emerald,
                secondaryColor: ArcticAuroraPalette.neonMint,
                highlightColor: ArcticAuroraPalette.lime,
                opacity: 0.13,
                driftDuration: 13,
                qualityMode: mode
            )
            .frame(height: 62)
            .offset(y: 66)
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    .clear,
                    ArcticAuroraPalette.pearl.opacity(0.12),
                    ArcticAuroraPalette.lime.opacity(0.10),
                    ArcticAuroraPalette.cyan.opacity(0.07),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 52)
            .blur(radius: 5)
            .offset(y: 58)
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    theme.arcticFrostColor.opacity(0.15),
                    ArcticAuroraPalette.neonMint.opacity(0.09),
                    ArcticAuroraPalette.violet.opacity(0.07),
                    ArcticAuroraPalette.magenta.opacity(0.06),
                    ArcticAuroraPalette.champagne.opacity(0.05),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

// MARK: - Solar Flare Shape

/// Layered flare wave used by Solar Pop backgrounds.
struct SolarFlareShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat
    let pulse: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let points: [(x: CGFloat, angle: CGFloat)]
    private static let sampleCount = 120

    init(
        amplitude: CGFloat = 0.06,
        frequency: CGFloat = 1.9,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.54,
        pulse: CGFloat = 0.22
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.pulse = pulse

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
            let harmonic = sin(pt.angle * 2.35 + phase * 0.82)
            let spikeSeed = sin(pt.angle * 3.5 + phase * 1.1)
            let spike = Swift.max(0, spikeSeed) * pulse
            let y = centerY + amp * (base * 0.7 + harmonic * 0.2 - spike * 0.65)
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

// MARK: - Solar Flare Overlay

struct SolarFlareOverlayView: View {
    var color: Color
    var opacity: Double = 0.14
    var amplitude: CGFloat = 0.06
    var frequency: CGFloat = 1.8
    var verticalOffset: CGFloat = 0.54
    var bottomFade: CGFloat = 0.48
    var pulse: CGFloat = 0.2
    var driftDuration: Double = 12
    var reverseDirection: Bool = false
    var strokeColor: Color? = nil
    var strokeOpacity: Double = 0.24
    var strokeWidth: CGFloat = 1.1

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var targetPhase: CGFloat {
        (reverseDirection ? -1 : 1) * 2 * .pi
    }

    var body: some View {
        let flare = SolarFlareShape(
            amplitude: amplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset,
            pulse: pulse
        )

        ZStack {
            flare
                .fill(color.opacity(opacity))
                .bottomFadeMask(bottomFade)

            if let strokeColor {
                flare
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

// MARK: - Solar Pop Backgrounds

struct SolarTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2
        case .today:    1.0
        case .wellness: 0.82
        case .life:     0.68
        }
    }

    private var darkBoost: Double {
        colorScheme == .dark ? 1.16 : 1.0
    }

    var body: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * darkBoost

        ZStack(alignment: .top) {
            SolarFlareOverlayView(
                color: theme.solarEmberColor,
                opacity: 0.08 * opacityScale,
                amplitude: 0.028 * scale,
                frequency: 1.0,
                verticalOffset: 0.40,
                bottomFade: 0.54,
                pulse: 0.10,
                driftDuration: 18,
                strokeColor: theme.solarCoreColor,
                strokeOpacity: 0.12 * opacityScale,
                strokeWidth: 0.8
            )
            .frame(height: 200)

            SolarFlareOverlayView(
                color: theme.solarCoreColor,
                opacity: 0.17 * opacityScale,
                amplitude: 0.072 * scale,
                frequency: 1.7,
                verticalOffset: 0.50,
                bottomFade: 0.48,
                pulse: 0.22,
                driftDuration: 13,
                reverseDirection: true,
                strokeColor: theme.solarGlowColor,
                strokeOpacity: 0.25 * opacityScale,
                strokeWidth: 1.3
            )
            .frame(height: 200)

            SolarFlareOverlayView(
                color: theme.solarGlowColor,
                opacity: 0.22 * opacityScale,
                amplitude: 0.102 * scale,
                frequency: 2.3,
                verticalOffset: 0.58,
                bottomFade: 0.44,
                pulse: 0.28,
                driftDuration: 10,
                strokeColor: theme.solarCoreColor,
                strokeOpacity: 0.32 * opacityScale,
                strokeWidth: 1.8
            )
            .frame(height: 200)

            LinearGradient(
                colors: [
                    theme.solarGlowColor.opacity(colorScheme == .dark ? 0.26 : 0.20),
                    theme.solarCoreColor.opacity(colorScheme == .dark ? 0.16 : 0.12),
                    theme.solarEmberColor.opacity(colorScheme == .dark ? 0.10 : 0.07),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

struct SolarDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            SolarFlareOverlayView(
                color: theme.solarEmberColor,
                opacity: 0.08,
                amplitude: 0.024,
                frequency: 1.0,
                verticalOffset: 0.42,
                bottomFade: 0.58,
                pulse: 0.09,
                driftDuration: 15,
                strokeColor: theme.solarCoreColor,
                strokeOpacity: 0.10,
                strokeWidth: 0.7
            )
            .frame(height: 150)

            SolarFlareOverlayView(
                color: theme.solarCoreColor,
                opacity: 0.13,
                amplitude: 0.046,
                frequency: 1.58,
                verticalOffset: 0.52,
                bottomFade: 0.52,
                pulse: 0.18,
                driftDuration: 12,
                reverseDirection: true,
                strokeColor: theme.solarGlowColor,
                strokeOpacity: 0.18,
                strokeWidth: 1.0
            )
            .frame(height: 150)

            SolarFlareOverlayView(
                color: theme.solarGlowColor,
                opacity: 0.17,
                amplitude: 0.062,
                frequency: 2.0,
                verticalOffset: 0.56,
                bottomFade: 0.50,
                pulse: 0.22,
                driftDuration: 10,
                strokeColor: theme.solarCoreColor,
                strokeOpacity: 0.22,
                strokeWidth: 1.2
            )
            .frame(height: 150)

            LinearGradient(
                colors: [theme.solarGlowColor.opacity(DS.Opacity.light), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

struct SolarSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            SolarFlareOverlayView(
                color: theme.solarCoreColor,
                opacity: 0.10,
                amplitude: 0.034,
                frequency: 1.52,
                verticalOffset: 0.50,
                bottomFade: 0.56,
                pulse: 0.14,
                driftDuration: 12,
                reverseDirection: true,
                strokeColor: theme.solarGlowColor,
                strokeOpacity: 0.16,
                strokeWidth: 0.9
            )
            .frame(height: 120)

            SolarFlareOverlayView(
                color: theme.solarGlowColor,
                opacity: 0.14,
                amplitude: 0.050,
                frequency: 1.92,
                verticalOffset: 0.55,
                bottomFade: 0.52,
                pulse: 0.19,
                driftDuration: 10,
                strokeColor: theme.solarCoreColor,
                strokeOpacity: 0.20,
                strokeWidth: 1.1
            )
            .frame(height: 120)

            LinearGradient(
                colors: [theme.solarGlowColor.opacity(DS.Opacity.light), .clear],
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

#Preview("Solar Tab — Dark") {
    SolarTabWaveBackground()
        .environment(\.appTheme, .solarPop)
        .preferredColorScheme(.dark)
}
