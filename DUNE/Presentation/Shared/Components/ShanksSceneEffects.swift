import SwiftUI

struct ShanksSceneStyle {
    let sceneHeight: CGFloat
    let sceneTopInset: CGFloat
    let gradientEndPoint: UnitPoint
    let waveScale: CGFloat
    let deepOpacity: Double
    let midOpacity: Double
    let surfaceOpacity: Double
    let accentOpacity: Double
    let foamOpacity: Double
    let causticOpacity: Double
    let textureOpacity: Double
    let flagOpacity: Double
    let shipOpacity: Double
    let shipScale: CGFloat
    let shipOffsetX: CGFloat
    let shipTopPadding: CGFloat
    let wakeOpacity: Double
    let kamusariOpacity: Double
    let kamusariScale: CGFloat
    let fishCount: Int
    let fishOpacity: Double
    let fishScale: CGFloat
}

extension ShanksSceneStyle {
    static func tab(for preset: WavePreset) -> Self {
        let scale: CGFloat
        let topInset: CGFloat
        let fishCount: Int
        let fishOpacity: Double
        let fishScale: CGFloat
        switch preset {
        case .train:
            scale = 1.18
            topInset = 104
            fishCount = 3
            fishOpacity = 0.22
            fishScale = 1.08
        case .today:
            scale = 1.0
            topInset = 100
            fishCount = 3
            fishOpacity = 0.20
            fishScale = 1.0
        case .wellness:
            scale = 0.84
            topInset = 96
            fishCount = 2
            fishOpacity = 0.16
            fishScale = 0.88
        case .life:
            scale = 0.70
            topInset = 64
            fishCount = 2
            fishOpacity = 0.14
            fishScale = 0.74
        }

        return .init(
            sceneHeight: 228,
            sceneTopInset: topInset,
            gradientEndPoint: DS.Gradient.tabBackgroundEnd,
            waveScale: scale,
            deepOpacity: 0.30,
            midOpacity: 0.24,
            surfaceOpacity: 0.20,
            accentOpacity: 0.14,
            foamOpacity: 0.82,
            causticOpacity: 0.78,
            textureOpacity: 0.10,
            flagOpacity: 0.16,
            shipOpacity: 0.92,
            shipScale: scale,
            shipOffsetX: 0,
            shipTopPadding: 76,
            wakeOpacity: 0.54,
            kamusariOpacity: 0.88,
            kamusariScale: scale,
            fishCount: fishCount,
            fishOpacity: fishOpacity,
            fishScale: fishScale
        )
    }

    static let detail = Self(
        sceneHeight: 164,
        sceneTopInset: 88,
        gradientEndPoint: DS.Gradient.tabBackgroundEnd,
        waveScale: 0.82,
        deepOpacity: 0.22,
        midOpacity: 0.18,
        surfaceOpacity: 0.15,
        accentOpacity: 0.10,
        foamOpacity: 0.62,
        causticOpacity: 0.48,
        textureOpacity: 0.06,
        flagOpacity: 0.10,
        shipOpacity: 0.72,
        shipScale: 0.82,
        shipOffsetX: -4,
        shipTopPadding: 46,
        wakeOpacity: 0.34,
        kamusariOpacity: 0.58,
        kamusariScale: 0.78,
        fishCount: 2,
        fishOpacity: 0.11,
        fishScale: 0.82
    )

    static let sheet = Self(
        sceneHeight: 124,
        sceneTopInset: 56,
        gradientEndPoint: DS.Gradient.sheetBackgroundEnd,
        waveScale: 0.64,
        deepOpacity: 0.16,
        midOpacity: 0.14,
        surfaceOpacity: 0.10,
        accentOpacity: 0.06,
        foamOpacity: 0.42,
        causticOpacity: 0.28,
        textureOpacity: 0.04,
        flagOpacity: 0.06,
        shipOpacity: 0.56,
        shipScale: 0.66,
        shipOffsetX: -8,
        shipTopPadding: 24,
        wakeOpacity: 0.20,
        kamusariOpacity: 0.36,
        kamusariScale: 0.62,
        fishCount: 1,
        fishOpacity: 0.07,
        fishScale: 0.62
    )
}

struct ShanksCinematicSceneBackground: View {
    let style: ShanksSceneStyle
    let accentTint: Color?
    let sceneTopInsetOverride: CGFloat?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var resolvedAccentTint: Color {
        accentTint ?? theme.shanksGlowColor
    }

    private var resolvedSceneTopInset: CGFloat {
        if let sceneTopInsetOverride {
            return max(sceneTopInsetOverride, 0)
        }
        return style.sceneTopInset + (sizeClass == .regular ? 20 : 0)
    }

    private var gradientColors: [Color] {
        let darkBoost = colorScheme == .dark ? 1.0 : 0.84
        return [
            theme.shanksAbyssColor.opacity(0.94),
            theme.shanksCurrentColor.opacity(0.38 * darkBoost),
            theme.shanksDeepColor.opacity(0.22 * darkBoost),
            theme.shanksCoreColor.opacity(0.10 * darkBoost),
            .clear,
        ]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .top,
                    endPoint: style.gradientEndPoint
                )

                // Keep the atmospheric tint at the top, but push the ocean scene
                // itself below the hero card's lower quarter.
                ZStack(alignment: .top) {
                    ShanksWaterMassScene(
                        style: style,
                        accentTint: resolvedAccentTint
                    )
                    .frame(height: style.sceneHeight)

                    ShanksDeepSeaFishOverlay(
                        style: style,
                        elapsed: elapsed
                    )
                    .frame(height: style.sceneHeight)

                    ShanksUnderwaterCausticOverlay(
                        style: style,
                        elapsed: elapsed
                    )
                    .frame(height: style.sceneHeight)

                    ShanksFlagTextureView(opacity: style.textureOpacity * (colorScheme == .dark ? 1.0 : 0.86))
                        .frame(height: style.sceneHeight)
                        .mask(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.9),
                                    Color.black.opacity(0.55),
                                    .clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    if style.flagOpacity > 0 {
                        ShanksSceneFlagOverlay(
                            opacity: style.flagOpacity,
                            width: style.sceneHeight * 0.64
                        )
                        .frame(height: style.sceneHeight)
                    }

                    ShanksShipHeroOverlay(
                        style: style,
                        elapsed: elapsed
                    )
                    .frame(height: style.sceneHeight)

                    ShanksSurfaceFoamOverlay(
                        style: style,
                        elapsed: elapsed
                    )
                    .frame(height: style.sceneHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, resolvedSceneTopInset)
            }
            .ignoresSafeArea()
        }
    }
}

private struct ShanksWaterMassScene: View {
    let style: ShanksSceneStyle
    let accentTint: Color

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var darkBoost: Double {
        colorScheme == .dark ? 1.0 : 0.82
    }

    var body: some View {
        ZStack(alignment: .top) {
            OceanWaveOverlayView(
                color: theme.shanksAbyssColor,
                opacity: style.deepOpacity * darkBoost,
                amplitude: 0.035 * style.waveScale,
                frequency: 0.86,
                verticalOffset: 0.36,
                bottomFade: 0.46,
                steepness: 0.18,
                harmonicOffset: .pi / 6,
                crestHeight: 0.14 * style.waveScale,
                crestSharpness: 0.03 * style.waveScale,
                driftDuration: 20,
                strokeStyle: WaveStrokeStyle(
                    color: theme.shanksCurrentColor,
                    width: 0.6,
                    opacity: 0.10 * darkBoost
                )
            )

            OceanWaveOverlayView(
                color: theme.shanksCurrentColor,
                opacity: style.midOpacity * darkBoost,
                amplitude: 0.056 * style.waveScale,
                frequency: 1.42,
                verticalOffset: 0.47,
                bottomFade: 0.42,
                steepness: 0.28,
                harmonicOffset: .pi / 4,
                crestHeight: 0.24 * style.waveScale,
                crestSharpness: 0.08 * style.waveScale,
                driftDuration: 15,
                reverseDirection: true,
                strokeStyle: WaveStrokeStyle(
                    color: theme.shanksFoamColor,
                    width: 1.0,
                    opacity: 0.18 * darkBoost
                )
            )

            OceanWaveOverlayView(
                color: accentTint,
                opacity: style.accentOpacity * darkBoost,
                amplitude: 0.050 * style.waveScale,
                frequency: 1.72,
                verticalOffset: 0.50,
                bottomFade: 0.52,
                steepness: 0.34,
                harmonicOffset: .pi / 3,
                crestHeight: 0.24 * style.waveScale,
                crestSharpness: 0.10 * style.waveScale,
                driftDuration: 12,
                strokeStyle: WaveStrokeStyle(
                    color: theme.shanksFoamColor,
                    width: 0.8,
                    opacity: 0.12 * darkBoost
                )
            )

            OceanWaveOverlayView(
                color: theme.shanksCurrentColor,
                opacity: style.surfaceOpacity * darkBoost,
                amplitude: 0.024 * style.waveScale,
                frequency: 1.18,
                verticalOffset: 0.20,
                bottomFade: 0.66,
                steepness: 0.18,
                harmonicOffset: .pi / 7,
                crestHeight: 0.12 * style.waveScale,
                crestSharpness: 0.07 * style.waveScale,
                driftDuration: 10,
                reverseDirection: true,
                strokeStyle: WaveStrokeStyle(
                    color: theme.shanksFoamColor,
                    width: 1.1,
                    opacity: 0.20 * darkBoost
                )
            )

            LinearGradient(
                colors: [
                    theme.shanksAbyssColor.opacity(0.44),
                    theme.shanksCurrentColor.opacity(0.18),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }
}

private struct ShanksUnderwaterCausticOverlay: View {
    let style: ShanksSceneStyle
    let elapsed: TimeInterval

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private struct StrandSpec {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let rotation: Double
        let speed: Double
        let opacity: Double
    }

    private static let strands: [StrandSpec] = [
        .init(x: 0.16, y: 0.28, width: 0.16, height: 0.018, rotation: -14, speed: 0.78, opacity: 0.72),
        .init(x: 0.31, y: 0.34, width: 0.22, height: 0.020, rotation: 11, speed: 0.92, opacity: 0.68),
        .init(x: 0.50, y: 0.26, width: 0.19, height: 0.015, rotation: -8, speed: 0.86, opacity: 0.74),
        .init(x: 0.66, y: 0.36, width: 0.24, height: 0.021, rotation: 16, speed: 1.08, opacity: 0.66),
        .init(x: 0.82, y: 0.24, width: 0.18, height: 0.016, rotation: -12, speed: 0.82, opacity: 0.64),
        .init(x: 0.70, y: 0.48, width: 0.22, height: 0.017, rotation: -6, speed: 0.70, opacity: 0.54),
    ]

    private static let sparkleSeeds: [CGFloat] = [0.11, 0.19, 0.28, 0.39, 0.52, 0.63, 0.74, 0.86]

    var body: some View {
        GeometryReader { proxy in
            causticCanvas(size: proxy.size)
        }
        .allowsHitTesting(false)
    }

    private func causticCanvas(size: CGSize) -> some View {
        let shimmerShader = ShaderLibrary.shanksSeaShimmer(
            .float(Float(elapsed)),
            .float2(shaderPoint(size)),
            .float(Float(style.causticOpacity))
        )
        let maskGradient = LinearGradient(
            colors: [
                Color.black.opacity(0.9),
                Color.black.opacity(0.52),
                .clear,
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        return Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            guard size.width > 0, size.height > 0 else { return }

            context.drawLayer { layer in
                layer.blendMode = .screen
                layer.addFilter(.blur(radius: colorScheme == .dark ? 2.6 : 2.1))

                for index in Self.strands.indices {
                    let strand = Self.strands[index]
                    let x = size.width * strand.x + sin(elapsed * strand.speed + Double(index)) * size.width * 0.02
                    let y = size.height * strand.y + cos(elapsed * strand.speed * 0.7 + Double(index) * 0.4) * size.height * 0.018
                    let width = size.width * strand.width
                    let height = max(size.height * strand.height, 1.4)
                    let rotation = strand.rotation + sin(elapsed * strand.speed) * 4
                    let path = transformedCapsulePath(
                        width: width,
                        height: height,
                        centerX: x,
                        centerY: y,
                        rotation: rotation
                    )
                    let colors = [
                        theme.shanksCausticColor.opacity(style.causticOpacity * strand.opacity),
                        theme.shanksFoamColor.opacity(style.causticOpacity * strand.opacity * 0.74),
                        Color.clear,
                    ]

                    layer.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: colors),
                            startPoint: CGPoint(x: x - width * 0.5, y: y),
                            endPoint: CGPoint(x: x + width * 0.5, y: y)
                        )
                    )
                }
            }

            for index in Self.sparkleSeeds.indices {
                let seed = Self.sparkleSeeds[index]
                let x = size.width * seed
                let y = size.height * (0.22 + 0.16 * abs(sin(CGFloat(elapsed) * 0.6 + seed * 9)))
                let sparkleSize = 1.4 + CGFloat(index % 3) * 0.8
                let sparklePath = Path(ellipseIn: CGRect(x: x, y: y, width: sparkleSize, height: sparkleSize))
                var sparkleContext = context
                sparkleContext.blendMode = .plusLighter
                sparkleContext.fill(
                    sparklePath,
                    with: .color(theme.shanksFoamColor.opacity(style.causticOpacity * 0.28))
                )
            }
        }
        .colorEffect(shimmerShader)
        .mask(maskGradient)
        .opacity(colorScheme == .dark ? 1.0 : 0.86)
    }

    private func transformedCapsulePath(
        width: CGFloat,
        height: CGFloat,
        centerX: CGFloat,
        centerY: CGFloat,
        rotation: Double
    ) -> Path {
        let capsule = Path(
            roundedRect: CGRect(
                x: -width / 2,
                y: -height / 2,
                width: width,
                height: height
            ),
            cornerRadius: height / 2
        )

        let transform = CGAffineTransform(rotationAngle: CGFloat(rotation) * .pi / 180)
            .concatenating(CGAffineTransform(translationX: centerX, y: centerY))

        return capsule.applying(transform)
    }
}

struct ShanksDeepSeaFishSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.04, y: h * 0.48))
        path.addCurve(
            to: CGPoint(x: w * 0.22, y: h * 0.18),
            control1: CGPoint(x: w * 0.08, y: h * 0.26),
            control2: CGPoint(x: w * 0.15, y: h * 0.14)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.58, y: h * 0.20),
            control1: CGPoint(x: w * 0.34, y: h * 0.06),
            control2: CGPoint(x: w * 0.48, y: h * 0.10)
        )
        path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.04))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.22))
        path.addCurve(
            to: CGPoint(x: w * 0.86, y: h * 0.38),
            control1: CGPoint(x: w * 0.74, y: h * 0.20),
            control2: CGPoint(x: w * 0.82, y: h * 0.26)
        )
        path.addLine(to: CGPoint(x: w * 1.00, y: h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 1.00, y: h * 0.88))
        path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.62))
        path.addCurve(
            to: CGPoint(x: w * 0.54, y: h * 0.76),
            control1: CGPoint(x: w * 0.76, y: h * 0.76),
            control2: CGPoint(x: w * 0.64, y: h * 0.82)
        )
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.74))
        path.addCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.66),
            control1: CGPoint(x: w * 0.32, y: h * 0.76),
            control2: CGPoint(x: w * 0.24, y: h * 0.72)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.04, y: h * 0.48),
            control1: CGPoint(x: w * 0.08, y: h * 0.64),
            control2: CGPoint(x: w * 0.04, y: h * 0.56)
        )
        path.closeSubpath()

        return path
    }
}

private struct ShanksDeepSeaFishOverlay: View {
    let style: ShanksSceneStyle
    let elapsed: TimeInterval

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private struct FishSpec {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let rotation: Double
        let speed: Double
        let phase: Double
        let opacity: Double
        let blur: CGFloat
        let mirrored: Bool
    }

    private static let specs: [FishSpec] = [
        .init(x: 0.22, y: 0.70, width: 0.34, height: 0.22, rotation: -8, speed: 0.16, phase: 0.4, opacity: 1.00, blur: 1.0, mirrored: false),
        .init(x: 0.80, y: 0.48, width: 0.26, height: 0.18, rotation: 7, speed: 0.21, phase: 1.7, opacity: 0.74, blur: 1.8, mirrored: true),
        .init(x: 0.56, y: 0.82, width: 0.20, height: 0.14, rotation: -3, speed: 0.28, phase: 2.8, opacity: 0.56, blur: 2.4, mirrored: false),
    ]

    private var darkBoost: Double {
        colorScheme == .dark ? 1.0 : 0.84
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                ForEach(Array(Self.specs.prefix(style.fishCount).enumerated()), id: \.offset) { index, spec in
                    let width = min(max(size.width * spec.width * style.fishScale, 68), size.width * 0.44)
                    let height = max(size.height * spec.height * style.fishScale, 24)
                    let driftX = sin(elapsed * spec.speed + spec.phase) * size.width * 0.028
                    let driftY = cos(elapsed * spec.speed * 1.4 + spec.phase + Double(index)) * size.height * 0.018
                    let wobble = sin(elapsed * spec.speed * 2.0 + spec.phase) * 2.4

                    ShanksDeepSeaFishSilhouetteShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.shanksCurrentColor.opacity(style.fishOpacity * spec.opacity * 0.14 * darkBoost),
                                    theme.shanksDeepColor.opacity(style.fishOpacity * spec.opacity * 0.72 * darkBoost),
                                    theme.shanksAbyssColor.opacity(style.fishOpacity * spec.opacity * 0.94),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            ShanksDeepSeaFishSilhouetteShape()
                                .stroke(
                                    theme.shanksFoamColor.opacity(style.fishOpacity * spec.opacity * 0.08),
                                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)
                                )
                        }
                        .frame(width: width, height: height)
                        .scaleEffect(x: spec.mirrored ? -1 : 1, y: 1)
                        .rotationEffect(.degrees(spec.rotation + wobble))
                        .offset(
                            x: size.width * (spec.x - 0.5) + driftX,
                            y: size.height * (spec.y - 0.5) + driftY
                        )
                        .blur(radius: spec.blur)
                        .opacity(style.fishOpacity * spec.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}

private struct ShanksSceneFlagOverlay: View {
    let opacity: Double
    let width: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sway: CGFloat = -0.03

    var body: some View {
        ShanksPirateFlagMark()
            .frame(width: width, height: width)
            .scaleEffect(1.06)
            .rotationEffect(.degrees(-8 + Double(sway) * 6))
            .opacity(opacity)
            .blur(radius: 0.25)
            .padding(.top, width * 0.12)
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
            .task(id: reduceMotion) {
                guard !reduceMotion else { return }
                sway = -0.03
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    sway = 0.03
                }
            }
    }
}

struct ShanksFoamCrestShape: Shape {
    var amplitude: CGFloat = 0.06
    var frequency: CGFloat = 1.6
    var phase: CGFloat = 0
    var verticalOffset: CGFloat = 0.20
    var bandDepth: CGFloat = 0.10

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let sampleCount = max(56, Int(rect.width / 6))
        let centerY = rect.height * verticalOffset
        let amp = rect.height * amplitude
        let baseDepth = rect.height * bandDepth
        let angleStep = (2 * CGFloat.pi * frequency) / CGFloat(sampleCount - 1)

        var topPoints: [CGPoint] = []
        var bottomPoints: [CGPoint] = []
        topPoints.reserveCapacity(sampleCount)
        bottomPoints.reserveCapacity(sampleCount)

        for index in 0..<sampleCount {
            let progress = CGFloat(index) / CGFloat(sampleCount - 1)
            let angle = progress * 2 * .pi * frequency + phase
            let x = rect.minX + rect.width * progress
            let y = centerY
                + sin(angle) * amp
                + sin(angle * 2.1 + phase * 0.55) * amp * 0.28
            let depth = baseDepth * (0.82 + 0.18 * sin(angleStep * CGFloat(index) * 0.8 + phase * 0.4))

            topPoints.append(CGPoint(x: x, y: y))
            bottomPoints.append(CGPoint(x: x, y: y + depth))
        }

        var path = Path()
        path.move(to: topPoints[0])
        for point in topPoints.dropFirst() {
            path.addLine(to: point)
        }
        for point in bottomPoints.reversed() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

private struct ShanksSurfaceFoamOverlay: View {
    let style: ShanksSceneStyle
    let elapsed: TimeInterval

    @Environment(\.appTheme) private var theme

    var body: some View {
        let phase = CGFloat(elapsed) * 0.42

        ZStack(alignment: .top) {
            ShanksFoamCrestShape(
                amplitude: 0.050 * style.waveScale,
                frequency: 1.48,
                phase: phase,
                verticalOffset: 0.17,
                bandDepth: 0.10
            )
            .fill(
                LinearGradient(
                    colors: [
                        theme.shanksFoamColor.opacity(style.foamOpacity),
                        theme.shanksCausticColor.opacity(style.foamOpacity * 0.34),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blur(radius: 0.8)
            .blendMode(.screen)

            ShanksFoamCrestShape(
                amplitude: 0.032 * style.waveScale,
                frequency: 1.92,
                phase: -phase * 0.88 + .pi / 4,
                verticalOffset: 0.20,
                bandDepth: 0.08
            )
            .fill(
                LinearGradient(
                    colors: [
                        theme.shanksFoamColor.opacity(style.foamOpacity * 0.78),
                        theme.shanksCausticColor.opacity(style.foamOpacity * 0.18),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blendMode(.screen)

            ShanksFoamCrestShape(
                amplitude: 0.034 * style.waveScale,
                frequency: 1.62,
                phase: phase * 0.76 + .pi / 7,
                verticalOffset: 0.18,
                bandDepth: 0.05
            )
            .stroke(
                theme.shanksFoamColor.opacity(style.foamOpacity * 0.92),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )
            .blendMode(.screen)
        }
        .mask(
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.72),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
    }
}

struct ShanksRedForceSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let w = rect.width
        let h = rect.height
        var path = Path()

        // Hull
        path.move(to: CGPoint(x: w * 0.04, y: h * 0.68))
        path.addCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.72),
            control1: CGPoint(x: w * 0.08, y: h * 0.72),
            control2: CGPoint(x: w * 0.13, y: h * 0.74)
        )
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.72))
        path.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.60),
            control1: CGPoint(x: w * 0.87, y: h * 0.72),
            control2: CGPoint(x: w * 0.93, y: h * 0.66)
        )
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.52))
        path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.52))
        path.addCurve(
            to: CGPoint(x: w * 0.58, y: h * 0.46),
            control1: CGPoint(x: w * 0.70, y: h * 0.51),
            control2: CGPoint(x: w * 0.64, y: h * 0.47)
        )
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.52))
        path.closeSubpath()

        // Main mast
        path.addRoundedRect(
            in: CGRect(x: w * 0.47, y: h * 0.14, width: w * 0.024, height: h * 0.40),
            cornerSize: CGSize(width: w * 0.012, height: w * 0.012)
        )

        // Fore mast
        path.addRoundedRect(
            in: CGRect(x: w * 0.33, y: h * 0.28, width: w * 0.018, height: h * 0.22),
            cornerSize: CGSize(width: w * 0.009, height: w * 0.009)
        )

        // Aft mast
        path.addRoundedRect(
            in: CGRect(x: w * 0.62, y: h * 0.24, width: w * 0.018, height: h * 0.26),
            cornerSize: CGSize(width: w * 0.009, height: w * 0.009)
        )

        // Main sail
        path.move(to: CGPoint(x: w * 0.49, y: h * 0.16))
        path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.29))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.56))
        path.closeSubpath()

        // Fore sail
        path.move(to: CGPoint(x: w * 0.34, y: h * 0.29))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.36))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.51))
        path.closeSubpath()

        // Aft sail
        path.move(to: CGPoint(x: w * 0.63, y: h * 0.25))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.33))
        path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.47))
        path.closeSubpath()

        // Pennant
        path.move(to: CGPoint(x: w * 0.49, y: h * 0.14))
        path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.17))
        path.closeSubpath()

        return path
    }
}

private struct ShanksShipWakeOverlay: View {
    let opacity: Double
    let elapsed: TimeInterval

    @Environment(\.appTheme) private var theme

    private struct WakeSpec {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let rotation: Double
    }

    private static let specs: [WakeSpec] = [
        .init(x: 0.24, y: 0.62, width: 0.30, height: 0.08, rotation: -9),
        .init(x: 0.42, y: 0.56, width: 0.22, height: 0.07, rotation: -4),
        .init(x: 0.12, y: 0.74, width: 0.24, height: 0.07, rotation: 7),
    ]

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            guard size.width > 0, size.height > 0 else { return }

            context.drawLayer { layer in
                layer.blendMode = .screen
                layer.addFilter(.blur(radius: 1.2))

                for index in Self.specs.indices {
                    let spec = Self.specs[index]
                    let driftX = sin(elapsed * 0.8 + Double(index) * 0.7) * size.width * 0.03
                    let driftY = cos(elapsed * 0.6 + Double(index) * 0.5) * size.height * 0.02
                    let width = size.width * spec.width
                    let height = size.height * spec.height
                    let centerX = size.width * spec.x + driftX + width * 0.5
                    let centerY = size.height * spec.y + driftY + height * 0.5
                    let path = Path(
                        roundedRect: CGRect(
                            x: -width / 2,
                            y: -height / 2,
                            width: width,
                            height: height
                        ),
                        cornerRadius: height / 2
                    )
                    .applying(
                        CGAffineTransform(rotationAngle: CGFloat(spec.rotation) * .pi / 180)
                            .concatenating(CGAffineTransform(translationX: centerX, y: centerY))
                    )

                    layer.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                theme.shanksFoamColor.opacity(opacity * 0.92),
                                theme.shanksCausticColor.opacity(opacity * 0.54),
                                .clear,
                            ]),
                            startPoint: CGPoint(x: 0, y: size.height * 0.5),
                            endPoint: CGPoint(x: size.width, y: size.height * 0.5)
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ShanksKamusariFieldOverlay: View {
    let intensity: Double
    let elapsed: TimeInterval

    @Environment(\.appTheme) private var theme

    private struct ArcSpec {
        let inset: CGFloat
        let start: CGFloat
        let end: CGFloat
        let lineWidth: CGFloat
        let rotation: Double
        let opacity: Double
    }

    private static let arcs: [ArcSpec] = [
        .init(inset: 0, start: 0.08, end: 0.44, lineWidth: 2.8, rotation: -24, opacity: 0.92),
        .init(inset: 12, start: 0.20, end: 0.63, lineWidth: 2.0, rotation: 18, opacity: 0.74),
        .init(inset: 24, start: 0.56, end: 0.90, lineWidth: 1.6, rotation: -6, opacity: 0.56),
    ]

    private static let streakAngles: [Double] = [-58, -22, 14, 42]

    var body: some View {
        GeometryReader { proxy in
            kamusariContent(size: proxy.size)
        }
        .allowsHitTesting(false)
    }

    private func kamusariContent(size: CGSize) -> some View {
        let glowShader = ShaderLibrary.shanksKamusariGlow(
            .float(Float(elapsed)),
            .float2(shaderPoint(size)),
            .float(Float(intensity))
        )
        let warpShader = ShaderLibrary.shanksWaterWarp(
            .float(Float(elapsed)),
            .float2(shaderPoint(size)),
            .float(Float(intensity))
        )

        return ZStack {
            ForEach(Array(Self.arcs.enumerated()), id: \.offset) { index, arc in
                kamusariArcView(index: index, arc: arc, size: size)
            }

            ForEach(Array(Self.streakAngles.enumerated()), id: \.offset) { index, angle in
                kamusariStreakView(index: index, angle: angle, size: size)
            }
        }
        .drawingGroup()
        .colorEffect(glowShader)
        .distortionEffect(
            warpShader,
            maxSampleOffset: CGSize(width: 14 * intensity, height: 8 * intensity)
        )
        .blendMode(.screen)
    }

    private func kamusariArcView(index: Int, arc: ArcSpec, size: CGSize) -> some View {
        let colors = [
            theme.bronzeColor.opacity(intensity * arc.opacity),
            theme.shanksGlowColor.opacity(intensity * arc.opacity * 0.96),
            theme.shanksFoamColor.opacity(intensity * arc.opacity * 0.48),
            Color.clear,
        ]
        let width = max(size.width - arc.inset * 2, 0)
        let height = max(size.height - arc.inset * 1.2, 0)
        let rotation = arc.rotation + sin(elapsed * 0.7 + Double(index)) * 7

        return Ellipse()
            .trim(from: arc.start, to: arc.end)
            .stroke(
                AngularGradient(colors: colors, center: .center),
                style: StrokeStyle(lineWidth: arc.lineWidth, lineCap: .round)
            )
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
            .blur(radius: 0.35)
    }

    private func kamusariStreakView(index: Int, angle: Double, size: CGSize) -> some View {
        let colors = [
            Color.clear,
            theme.shanksGlowColor.opacity(intensity * 0.96),
            theme.bronzeColor.opacity(intensity * 0.68),
            Color.clear,
        ]
        let rotation = angle + sin(elapsed * 0.9 + Double(index)) * 4
        let offsetX = cos((angle - 8) * .pi / 180) * size.width * 0.06
        let offsetY = sin((angle - 8) * .pi / 180) * size.height * 0.10

        return Capsule()
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size.width * 0.68, height: 2.0)
            .rotationEffect(.degrees(rotation))
            .offset(x: offsetX, y: offsetY)
            .blur(radius: 0.45)
    }
}

private struct ShanksShipHeroOverlay: View {
    let style: ShanksSceneStyle
    let elapsed: TimeInterval

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shipWidth = min(max(size.width * 0.28, 116), 186) * style.shipScale
            let shipHeight = shipWidth * 0.58
            let shipX = size.width * 0.70 + style.shipOffsetX
            let shipY = min(style.shipTopPadding + shipHeight * 0.5, size.height * 0.72)
            let glowOpacity = colorScheme == .dark ? 0.20 : 0.14

            ZStack {
                ShanksShipWakeOverlay(
                    opacity: style.wakeOpacity,
                    elapsed: elapsed
                )
                .frame(width: shipWidth * 1.7, height: shipHeight)
                .offset(
                    x: shipX - size.width * 0.5 - shipWidth * 0.44,
                    y: shipY - size.height * 0.5 + shipHeight * 0.06
                )

                ShanksRedForceSilhouetteShape()
                    .fill(theme.shanksDeepColor.opacity(style.shipOpacity))
                    .overlay {
                        ShanksRedForceSilhouetteShape()
                            .stroke(
                                theme.shanksFoamColor.opacity(0.18),
                                style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
                            )
                    }
                    .overlay {
                        ShanksRedForceSilhouetteShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.shanksGlowColor.opacity(0.22),
                                        theme.bronzeColor.opacity(0.16),
                                        .clear,
                                    ],
                                    startPoint: .topTrailing,
                                    endPoint: .bottomLeading
                                )
                            )
                    }
                    .shadow(color: theme.shanksGlowColor.opacity(glowOpacity), radius: 12, y: 4)
                    .frame(width: shipWidth, height: shipHeight)
                    .offset(x: shipX - size.width * 0.5, y: shipY - size.height * 0.5)

                ShanksKamusariFieldOverlay(
                    intensity: style.kamusariOpacity,
                    elapsed: elapsed
                )
                .frame(width: shipWidth * 2.0 * style.kamusariScale, height: shipHeight * 1.9 * style.kamusariScale)
                .offset(
                    x: shipX - size.width * 0.5 + shipWidth * 0.06,
                    y: shipY - size.height * 0.5 - shipHeight * 0.12
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private func shaderPoint(_ size: CGSize) -> CGPoint {
    CGPoint(x: size.width, y: size.height)
}
