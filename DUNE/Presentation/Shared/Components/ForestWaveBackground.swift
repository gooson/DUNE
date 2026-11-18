import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Forest Wave-Specific Colors (File-Private)

/// Forest wave layer colors are only consumed by forest backgrounds.
/// Kept file-private to avoid polluting the shared AppTheme extension.
private extension AppTheme {
    var forestDeepColor: Color { Color("ForestDeep") }
    var forestMidColor: Color { Color("ForestTabLife") }
    var forestMistColor: Color { Color("ForestSand") }
}

// MARK: - Forest Wave Overlay View

/// Single animated forest silhouette layer with bokashi gradient and optional grain.
private struct ForestWaveOverlayView: View {
    var color: Color
    var opacity: Double = 0.10
    var amplitude: CGFloat = 0.05
    var frequency: CGFloat = 1.5
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0.4
    var treeDensity: CGFloat = 0.0
    var driftDuration: Double = 8
    var showGrain: Bool = false
    var grainOpacity: Double = 0.04
    var crestColor: Color? = nil
    var crestOpacity: Double = 0.18
    var crestWidth: CGFloat = 1.6

    @State private var phase: CGFloat = 0
    @Environment(\.waveReducedMotion) private var reduceMotion

    /// Seamless loop turns. Harmonic multipliers (0.55, 1.3, 1.8, 2.2) require
    /// LCM = 20 turns so every component completes an integer number of cycles.
    private static let phaseLoopTurns: CGFloat = 20
    private var phaseTarget: CGFloat { 2 * .pi * Self.phaseLoopTurns }
    private var phaseDuration: Double { driftDuration * Double(Self.phaseLoopTurns) }

    /// Shared shape instance for fill and crest strokes — avoids 3× identical init.
    private var silhouetteShape: ForestSilhouetteShape {
        ForestSilhouetteShape(
            amplitude: amplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset,
            treeDensity: treeDensity
        )
    }

    var body: some View {
        ZStack {
            silhouetteShape
                .fill(color.opacity(opacity))
                .bottomFadeMask(bottomFade)

            if let crestColor {
                ZStack {
                    // Wide translucent crest band.
                    silhouetteShape
                        .stroke(
                            crestColor.opacity(crestOpacity * 0.48),
                            style: StrokeStyle(lineWidth: crestWidth * 2.6, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 1.2)

                    // Core crest highlight line.
                    silhouetteShape
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
            withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
                phase = phaseTarget
            }
        }
        .onAppear {
            guard !reduceMotion, driftDuration > 0 else { return }
            Task { @MainActor in
                phase = 0
                withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
                    phase = phaseTarget
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

// MARK: - Forest Canopy Artwork

enum ForestCanopyMotion {
    struct Translation {
        let x: CGFloat
        let y: CGFloat
    }

    struct Fog {
        let opacity: Double
        let x: CGFloat
        let y: CGFloat
    }

    struct Frame {
        let frontFog: Fog
        let valleyFog: Fog
        let upperNeedles: Translation
        let lowerNeedles: Translation
    }

    private struct Keyframe {
        let position: Double
        let fog: Fog

        init(_ position: Double, _ opacity: Double, _ x: CGFloat = 0, _ y: CGFloat = 0) {
            self.position = position
            self.fog = Fog(opacity: opacity, x: x, y: y)
        }
    }

    static let period: TimeInterval = 24
    static let staticElapsed: TimeInterval = 9

    // Positions and translations follow the approved forest-veil and valley-bank CSS.
    private static let frontFog: [Keyframe] = [
        .init(0, 0.98),
        .init(0.29, 0.68, 0.03, 0.18),
        .init(0.57, 0.025, 0.10, 0.48),
        .init(0.69, 0.025, 0.10, 0.48),
        .init(0.84, 0.35, 0.06, 0.29),
        .init(1, 0.98)
    ]

    private static let valleyFog: [Keyframe] = [
        .init(0, 0.97),
        .init(0.33, 0.87, -0.03, 0.04),
        .init(0.64, 0.10, -0.10, 0.28),
        .init(0.71, 0.10, -0.10, 0.28),
        .init(0.88, 0.72, -0.05, 0.10),
        .init(1, 0.97)
    ]

    static func shouldAnimate(scenePhase: ScenePhase, reduceMotion: Bool, isLowPowerModeEnabled: Bool) -> Bool {
        scenePhase == .active && !reduceMotion && !isLowPowerModeEnabled
    }

    static func frame(at elapsed: TimeInterval) -> Frame {
        let seconds = max(0, elapsed)
        let position = seconds.truncatingRemainder(dividingBy: period) / period
        let upper = needleBreeze(elapsed: seconds, period: 7.8, phase: 1.4)
        let lower = needleBreeze(elapsed: seconds, period: 9.6, phase: 2.6)
        return Frame(
            frontFog: interpolate(frontFog, at: position),
            valleyFog: interpolate(valleyFog, at: position),
            upperNeedles: Translation(x: 0.0010 * upper, y: -0.0074 * upper),
            lowerNeedles: Translation(x: 0.0016 * lower, y: -0.0105 * lower)
        )
    }

    private static func interpolate(_ keyframes: [Keyframe], at position: Double) -> Fog {
        for index in keyframes.indices.dropFirst() {
            let next = keyframes[index]
            guard position <= next.position else { continue }

            let previous = keyframes[index - 1]
            let progress = easeInOut((position - previous.position) / (next.position - previous.position))
            let translationProgress = CGFloat(progress)
            return Fog(
                opacity: previous.fog.opacity + (next.fog.opacity - previous.fog.opacity) * progress,
                x: previous.fog.x + (next.fog.x - previous.fog.x) * translationProgress,
                y: previous.fog.y + (next.fog.y - previous.fog.y) * translationProgress
            )
        }
        return keyframes[0].fog
    }

    private static func needleBreeze(elapsed: TimeInterval, period: TimeInterval, phase: TimeInterval) -> CGFloat {
        let position = (elapsed + phase).truncatingRemainder(dividingBy: period) / period
        if position <= 0.42 {
            return CGFloat(easeInOut(position / 0.42))
        }
        if position < 0.92 {
            return 1 - CGFloat(easeInOut((position - 0.42) / 0.50))
        }
        return 0
    }

    /// Evaluates CSS ease-in-out (0.42, 0, 0.58, 1) at the supplied time.
    private static func easeInOut(_ progress: Double) -> Double {
        guard progress > 0, progress < 1 else { return progress }

        var lower = 0.0
        var upper = 1.0
        for _ in 0..<12 {
            let t = (lower + upper) * 0.5
            let inverse = 1 - t
            let x = 3 * inverse * inverse * t * 0.42 + 3 * inverse * t * t * 0.58 + t * t * t
            if x < progress {
                lower = t
            } else {
                upper = t
            }
        }
        let t = (lower + upper) * 0.5
        return t * t * (3 - 2 * t)
    }
}

/// Preserves the source proportions and aligns the tip masks and fog to the same print on every tab.
struct ForestCanopyArtwork: View {
    let preset: WavePreset

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.waveReducedMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var startedAt = Date.now

    private static let printAspect: CGFloat = 2061.0 / 763.0
    private static let darkPrintTint = Color(red: 0.71, green: 0.71, blue: 0.71)
    private static let darkFogTint = Color(red: 0.70, green: 0.76, blue: 0.72)
    private static let staticFrame = ForestCanopyMotion.frame(at: ForestCanopyMotion.staticElapsed)

    private var shouldAnimate: Bool {
        ForestCanopyMotion.shouldAnimate(
            scenePhase: scenePhase,
            reduceMotion: reduceMotion,
            isLowPowerModeEnabled: isLowPowerModeEnabled
        )
    }

    var body: some View {
        let isDark = colorScheme == .dark
        let isPlaying = shouldAnimate

        GeometryReader { geometry in
            let rect = printRect(in: geometry.size)
            ZStack {
                // The unmasked print stays outside the timeline, including the
                // trunk and all of the needles outside the two tip masks.
                printLayer("ForestCanopyPrint", in: rect, isDark: isDark)

                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isPlaying)) { timeline in
                    let motion = isPlaying
                        ? ForestCanopyMotion.frame(at: timeline.date.timeIntervalSince(startedAt))
                        : Self.staticFrame
                    movingLayers(in: rect, motion: motion, isDark: isDark)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: isPlaying) {
            if isPlaying { startedAt = .now }
        }
        .onReceive(NotificationCenter.default.mainThreadPublisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private func printRect(in size: CGSize) -> CGRect {
        let crop: UnitPoint
        switch preset {
        case .today:    crop = UnitPoint(x: 0.50, y: 0.53)
        case .train:    crop = UnitPoint(x: 0.73, y: 0.47)
        case .wellness: crop = UnitPoint(x: 0.27, y: 0.68)
        case .life:     crop = UnitPoint(x: 0.97, y: 0.83)
        }

        let overscanX = size.width * 0.06
        let overscanY = size.height * 0.06
        let frameWidth = size.width + overscanX * 2
        let frameHeight = size.height + overscanY * 2
        let width = max(frameWidth, frameHeight * Self.printAspect)
        let height = width / Self.printAspect
        return CGRect(
            x: (frameWidth - width) * crop.x - overscanX,
            y: (frameHeight - height) * crop.y - overscanY,
            width: width,
            height: height
        )
    }

    private func movingLayers(in rect: CGRect, motion: ForestCanopyMotion.Frame, isDark: Bool) -> some View {
        ZStack {
            printLayer("ForestCanopyUpperTips", in: rect, isDark: isDark)
                .offset(x: rect.width * motion.upperNeedles.x, y: rect.height * motion.upperNeedles.y)
            printLayer("ForestCanopyLowerTips", in: rect, isDark: isDark)
                .offset(x: rect.width * motion.lowerNeedles.x, y: rect.height * motion.lowerNeedles.y)

            fogLayer(
                in: CGRect(x: rect.minX - rect.width * 0.24, y: rect.minY + rect.height * 0.28,
                           width: rect.width * 1.48, height: rect.height * 0.92),
                motion: motion.valleyFog,
                isDark: isDark
            )
            fogLayer(
                in: CGRect(x: rect.minX - rect.width * 0.25, y: rect.minY - rect.height * 0.68,
                           width: rect.width * 1.50, height: rect.height * 1.92),
                motion: motion.frontFog,
                isDark: isDark
            )
        }
    }

    private func printLayer(_ name: String, in rect: CGRect, isDark: Bool) -> some View {
        Image(decorative: name)
            .resizable()
            .frame(width: rect.width, height: rect.height)
            .saturation(isDark ? 0.83 : 0.94)
            .colorMultiply(isDark ? Self.darkPrintTint : .white)
            .position(x: rect.midX, y: rect.midY)
    }

    private func fogLayer(in rect: CGRect, motion: ForestCanopyMotion.Fog, isDark: Bool) -> some View {
        Image(decorative: "ForestValleyFog")
            .resizable()
            .frame(width: rect.width, height: rect.height)
            .colorMultiply(isDark ? Self.darkFogTint : .white)
            .position(x: rect.midX, y: rect.midY)
            .offset(x: rect.width * motion.x, y: rect.height * motion.y)
            .opacity(motion.opacity)
    }
}

// MARK: - Forest Tab Background

/// Root tabs use the canopy, while secondary screens keep the original treeline.
struct ForestTabWaveBackground: View {
    enum Artwork {
        case canopy
        case silhouettes
    }

    var artwork: Artwork = .canopy

    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    private static let titleMask = LinearGradient(
        stops: [
            .init(color: .black.opacity(0.18), location: 0),
            .init(color: .black.opacity(0.22), location: 0.27),
            .init(color: .black, location: 0.59)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    private static let statusBarMask = LinearGradient(
        stops: [
            .init(color: .black.opacity(0.40), location: 0),
            .init(color: .black.opacity(0.52), location: 0.14),
            .init(color: .black, location: 0.27)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Dark mode needs a small visibility lift for low-contrast forest tones.
    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.35 : 1.0
    }

    /// Scale factor based on tab preset character.
    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2   // Dense forest
        case .today:    1.0
        case .wellness: 0.8   // Gentle grove
        case .life:     0.6   // Misty meadow
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if artwork == .silhouettes {
                silhouetteLayers
            }

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

            if artwork == .canopy && preset == .today {
                ForestCanopyArtwork(preset: .today)
                    .frame(height: 226)
                    .mask(Self.titleMask)
                    .mask(Self.statusBarMask)
                    .bottomFadeMask(0.18)
            }
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }

    @ViewBuilder
    private var silhouetteLayers: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * visibilityBoost

        // Layer 1: Far — distant misty treeline (smallest trees, lightest)
        ForestWaveOverlayView(
            color: theme.forestMistColor,
            opacity: 0.23 * opacityScale,
            amplitude: 0.11 * scale,
            frequency: 0.9,
            verticalOffset: 0.40,
            bottomFade: 0.5,
            treeDensity: 0.45,
            driftDuration: 35,
            crestColor: theme.forestMistColor,
            crestOpacity: 0.10 * opacityScale,
            crestWidth: 1
        )
        .frame(height: 190)

        // A pale break keeps the distant canopy visible above the middle ridge at rest.
        LinearGradient(
            colors: [.clear, theme.forestMistColor.opacity(0.13 * opacityScale), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 38)
        .offset(y: 65)

        // Layer 2: Mid — middle-distance forest (medium trees)
        ForestWaveOverlayView(
            color: theme.forestMidColor,
            opacity: 0.38 * opacityScale,
            amplitude: 0.10 * scale,
            frequency: 1.65,
            verticalOffset: 0.64,
            bottomFade: 0.4,
            treeDensity: 1.4,
            driftDuration: 27,
            crestColor: theme.forestMistColor,
            crestOpacity: 0.12 * opacityScale,
            crestWidth: 1
        )
        .frame(height: 190)

        LinearGradient(
            colors: [.clear, theme.forestMistColor.opacity(0.11 * opacityScale), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 35)
        .offset(y: 108)

        // Layer 3: Near — foreground forest with tall conifers (darkest)
        ForestWaveOverlayView(
            color: theme.forestDeepColor,
            opacity: 0.57 * opacityScale,
            amplitude: 0.09 * scale,
            frequency: 2.7,
            verticalOffset: 0.87,
            bottomFade: 0.4,
            treeDensity: 1.3,
            driftDuration: 20,
            showGrain: true,
            grainOpacity: colorScheme == .dark ? 0.014 : 0.03,
            crestColor: theme.forestMidColor,
            crestOpacity: 0.55 * opacityScale,
            crestWidth: 1
        )
        .frame(height: 190)
    }

    private var forestGradientColors: [Color] {
        if preset == .today && atmosphere != .default {
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
/// Positioned at the bottom of the screen.
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
                opacity: 0.07 * visibilityBoost,
                amplitude: 0.20,
                frequency: 1.65,
                verticalOffset: 0.42,
                bottomFade: 0.5,
                treeDensity: 0.60,
                driftDuration: 22,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.09 * visibilityBoost,
                crestWidth: 1.0
            )
            .frame(height: 150)

            // Near — closer forest
            ForestWaveOverlayView(
                color: theme.forestDeepColor,
                opacity: 0.50 * visibilityBoost,
                amplitude: 0.30,
                frequency: 2.35,
                verticalOffset: 0.83,
                bottomFade: 0.45,
                treeDensity: 2.2,
                driftDuration: 18,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.13 * visibilityBoost,
                crestWidth: 1
            )
            .frame(height: 150)

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
                opacity: 0.10 * visibilityBoost,
                amplitude: 0.22,
                frequency: 0.6,
                verticalOffset: 0.40,
                bottomFade: 0.5,
                treeDensity: 0.60,
                driftDuration: 20,
                crestColor: theme.forestMistColor,
                crestOpacity: 0.11 * visibilityBoost,
                crestWidth: 1.3
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    .clear,
                    (colorScheme == .dark ? theme.forestMistColor : theme.forestMidColor).opacity(DS.Opacity.light)
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("ForestTabWaveBackground") {
    ForestTabWaveBackground()
        .environment(\.appTheme, .forestGreen)
}

#Preview("Forest Tab — All Presets") {
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
            ForestTabWaveBackground()
                .environment(\.wavePreset, preset)
                .environment(\.appTheme, .forestGreen)
                .overlay(alignment: .center) {
                    Text(name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .tabItem { Text(name) }
        }
    }
}

#Preview("Forest Tab — Dark") {
    ForestTabWaveBackground()
        .environment(\.appTheme, .forestGreen)
        .preferredColorScheme(.dark)
}
