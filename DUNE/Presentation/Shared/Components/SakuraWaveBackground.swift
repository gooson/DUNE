import SwiftUI
import UIKit

// MARK: - Sakura Wave-Specific Colors (File-Private)

private extension AppTheme {
    var sakuraPetalColor: Color { Color("SakuraPetal") }
    var sakuraIvoryColor: Color { Color("SakuraIvory") }
    var sakuraLeafColor: Color { Color("SakuraLeaf") }
}

// MARK: - Sakura Wave Overlay View

/// Single animated sakura layer with optional crest highlight and paper texture.
struct SakuraWaveOverlayView: View {
    var color: Color
    var opacity: Double = 0.12
    var amplitude: CGFloat = 0.05
    var frequency: CGFloat = 1.5
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0.4
    var petalDensity: CGFloat = 0.3
    var driftDuration: Double = 8
    var showTexture: Bool = false
    var textureOpacity: Double = 0.03
    var crestColor: Color? = nil
    var crestOpacity: Double = 0.16
    var crestWidth: CGFloat = 1.2

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Harmonized seamless loop for mixed harmonic factors used by SakuraPetalShape.
    private static let phaseLoopTurns: CGFloat = 20
    private var phaseTarget: CGFloat { 2 * .pi * Self.phaseLoopTurns }
    private var phaseDuration: Double { driftDuration * Double(Self.phaseLoopTurns) }

    private var petalShape: SakuraPetalShape {
        SakuraPetalShape(
            amplitude: amplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset,
            petalDensity: petalDensity
        )
    }

    var body: some View {
        ZStack {
            petalShape
                .fill(color.opacity(opacity))
                .bottomFadeMask(bottomFade)

            if let crestColor {
                ZStack {
                    petalShape
                        .stroke(
                            crestColor.opacity(crestOpacity * 0.45),
                            style: StrokeStyle(lineWidth: crestWidth * 2.4, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 1.0)

                    petalShape
                        .stroke(
                            crestColor.opacity(crestOpacity),
                            style: StrokeStyle(lineWidth: crestWidth, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 0.25)
                }
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.92), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.9)
                    )
                )
                .blendMode(.screen)
            }

            if showTexture {
                WashiTextureView(opacity: textureOpacity)
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

// MARK: - Washi Texture Overlay

/// Procedural paper texture rendered once as static image.
private struct WashiTextureView: View {
    let opacity: Double

    private static let textureImage: UIImage = {
        let size = CGSize(width: 420, height: 220)
        let step: CGFloat = 4
        let cols = Int(size.width / step)
        let rows = Int(size.height / step)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            for row in 0..<rows {
                for col in 0..<cols {
                    let seed = Double(row * 881 + col * 149)
                    let noise = sin(seed * 0.081) * sin(seed * 0.057) * sin(seed * 0.029)
                    let alpha = abs(noise) * 0.10
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
        Image(uiImage: Self.textureImage)
            .resizable()
            .interpolation(.none)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

// MARK: - Petal Drift Overlay

/// Low-count drifting petal overlay to provide explicit sakura identity.
private struct SakuraPetalDriftView: View {
    let intensity: Double
    let darkModeBoost: Double
    let petalCount: Int
    let speed: Double
    let petalColor: Color

    @State private var driftPhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var petals: [PetalSpec] {
        (0..<petalCount).map { idx in
            let seed = Double(idx * 139 + 17)
            let x = 0.05 + 0.9 * abs(sin(seed * 0.171))
            let y = -0.12 + 0.54 * abs(sin(seed * 0.137 + 0.7))
            let size = 5.0 + 8.0 * abs(sin(seed * 0.293))
            let sway = 6.0 + 14.0 * abs(sin(seed * 0.227 + 1.2))
            let start = 2 * Double.pi * abs(sin(seed * 0.043))
            let fallDepth = 0.62 + 0.58 * abs(sin(seed * 0.119 + 0.4))
            let fallRate = 0.65 + 0.9 * abs(sin(seed * 0.083 + 1.0))
            let spin = 18.0 + 42.0 * abs(sin(seed * 0.057))
            return PetalSpec(
                x: x,
                y: y,
                size: size,
                sway: sway,
                start: start,
                fallDepth: fallDepth,
                fallRate: fallRate,
                spin: spin
            )
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(petals.enumerated()), id: \.offset) { idx, petal in
                    let phase = driftPhase + CGFloat(petal.start)
                    let baseLoop = (phase / (2 * .pi)) * CGFloat(petal.fallRate)
                    let wrappedLoop = baseLoop.truncatingRemainder(dividingBy: 1)
                    let dropProgress = wrappedLoop < 0 ? wrappedLoop + 1 : wrappedLoop
                    let x = petal.x * proxy.size.width + CGFloat(sin(phase + CGFloat(idx))) * petal.sway
                    let yBase = petal.y * proxy.size.height
                    let yFall = proxy.size.height * CGFloat(petal.fallDepth) * dropProgress
                    let yDrift = reduceMotion ? 0 : CGFloat(cos(phase * 0.9 + CGFloat(idx) * 0.4)) * 6
                    SakuraPetalGlyph()
                        .fill(petalColor.opacity((0.26 + 0.32 * intensity) * darkModeBoost))
                        .frame(width: petal.size, height: petal.size * 1.35)
                        .rotationEffect(.degrees(Double(dropProgress * 160) + Double(phase) * petal.spin))
                        .position(x: x, y: yBase + yFall + yDrift)
                        .blur(radius: reduceMotion ? 0 : 0.2)
                }
            }
            .onAppear {
                startDriftIfNeeded()
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced {
                    driftPhase = 0
                } else {
                    startDriftIfNeeded()
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func startDriftIfNeeded() {
        guard !reduceMotion else {
            driftPhase = 0
            return
        }
        driftPhase = 0
        withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
            driftPhase = 2 * .pi
        }
    }
}

private struct PetalSpec {
    let x: Double
    let y: Double
    let size: Double
    let sway: Double
    let start: Double
    let fallDepth: Double
    let fallRate: Double
    let spin: Double
}

private struct SakuraPetalGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let left = CGPoint(x: rect.minX + rect.width * 0.14, y: rect.midY)
        let right = CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.midY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)

        path.move(to: top)
        path.addQuadCurve(to: right, control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2))
        path.addQuadCurve(to: bottom, control: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.maxY - rect.height * 0.08))
        path.addQuadCurve(to: left, control: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.08))
        path.addQuadCurve(to: top, control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2))
        path.addEllipse(in: CGRect(x: center.x - rect.width * 0.08, y: center.y - rect.height * 0.05, width: rect.width * 0.16, height: rect.height * 0.12))
        return path
    }
}

// MARK: - Sakura Tab Background

/// Multi-layer parallax blossom background for tab root screens.
struct SakuraTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.42 : 1.0
    }

    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.15
        case .today:    1.0
        case .wellness: 0.85
        case .life:     0.7
        }
    }

    var body: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * visibilityBoost

        ZStack(alignment: .top) {
            // Layer 1: Soft spring haze
            SakuraWaveOverlayView(
                color: theme.sakuraIvoryColor,
                opacity: 0.18 * opacityScale,
                amplitude: 0.20 * scale,
                frequency: 0.82,
                verticalOffset: 0.48,
                bottomFade: 0.55,
                petalDensity: 0.18,
                driftDuration: 38,
                crestColor: theme.sakuraPetalColor,
                crestOpacity: 0.10 * opacityScale,
                crestWidth: 1.0
            )
            .frame(height: 170)

            // Layer 2: Main blossom ridge
            SakuraWaveOverlayView(
                color: theme.sakuraPetalColor,
                opacity: 0.28 * opacityScale,
                amplitude: 0.24 * scale,
                frequency: 1.48,
                verticalOffset: 0.74,
                bottomFade: 0.42,
                petalDensity: 0.92,
                driftDuration: 28,
                showTexture: true,
                textureOpacity: colorScheme == .dark ? 0.020 : 0.03,
                crestColor: theme.sakuraIvoryColor,
                crestOpacity: 0.22 * opacityScale,
                crestWidth: 1.3
            )
            .frame(height: 185)

            // Layer 3: Deep branch/leaf anchor
            SakuraWaveOverlayView(
                color: theme.sakuraLeafColor,
                opacity: 0.30 * opacityScale,
                amplitude: 0.15 * scale,
                frequency: 1.75,
                verticalOffset: 0.88,
                bottomFade: 0.33,
                petalDensity: 0.25,
                driftDuration: 22,
                crestColor: theme.sakuraPetalColor,
                crestOpacity: 0.18 * opacityScale,
                crestWidth: 1.2
            )
            .frame(height: 190)

            // Layer 4: Main branch silhouette
            SakuraBranchShape(
                amplitude: 0.10 * scale,
                frequency: 1.1,
                phase: 0,
                verticalOffset: 0.76,
                twigDensity: 0.55
            )
            .stroke(
                theme.sakuraLeafColor.opacity(0.34 * opacityScale),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
            )
            .frame(height: 170)
            .blur(radius: colorScheme == .dark ? 0.2 : 0.35)

            // Layer 5: Foreground branch stroke
            SakuraBranchShape(
                amplitude: 0.12 * scale,
                frequency: 0.96,
                phase: CGFloat.pi * 0.22,
                verticalOffset: 0.66,
                twigDensity: 0.74
            )
            .stroke(
                theme.sakuraPetalColor.opacity(0.22 * opacityScale),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )
            .frame(height: 165)
            .blur(radius: colorScheme == .dark ? 0.1 : 0.2)

            // Layer 6: Distant branch stroke
            SakuraBranchShape(
                amplitude: 0.08 * scale,
                frequency: 1.42,
                phase: CGFloat.pi * 0.55,
                verticalOffset: 0.84,
                twigDensity: 0.46
            )
            .stroke(
                theme.sakuraLeafColor.opacity(0.20 * opacityScale),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
            )
            .frame(height: 175)
            .blur(radius: 0.35)

            // Layer 7: Drifting petals (identity cue)
            SakuraPetalDriftView(
                intensity: Double(scale),
                darkModeBoost: colorScheme == .dark ? 1.35 : 1.0,
                petalCount: preset == .life ? 14 : 24,
                speed: 14,
                petalColor: theme.sakuraPetalColor
            )

            LinearGradient(
                colors: sakuraGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        theme.sakuraIvoryColor.opacity(0.22),
                        theme.sakuraPetalColor.opacity(0.16),
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

    private var sakuraGradientColors: [Color] {
        if isWeatherActive {
            if colorScheme == .dark {
                return [
                    atmosphere.waveColor(for: theme).opacity(DS.Opacity.strong),
                    theme.sakuraIvoryColor.opacity(DS.Opacity.light),
                    .clear
                ]
            }
            return atmosphere.gradientColors(for: theme)
        }
        if colorScheme == .dark {
            return [
                theme.sakuraIvoryColor.opacity(0.24),
                theme.sakuraPetalColor.opacity(0.22),
                theme.sakuraLeafColor.opacity(0.16),
                .clear
            ]
        }
        return [
            theme.sakuraPetalColor.opacity(0.20),
            theme.sakuraIvoryColor.opacity(0.16),
            .clear
        ]
    }
}

// MARK: - Sakura Detail Background

/// Subtle 2-layer blossom background for detail screens.
struct SakuraDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.3 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            SakuraWaveOverlayView(
                color: theme.sakuraIvoryColor,
                opacity: 0.11 * visibilityBoost,
                amplitude: 0.18,
                frequency: 1.2,
                verticalOffset: 0.44,
                bottomFade: 0.52,
                petalDensity: 0.2,
                driftDuration: 28,
                crestColor: theme.sakuraPetalColor,
                crestOpacity: 0.12 * visibilityBoost,
                crestWidth: 1.0
            )
            .frame(height: 150)

            SakuraWaveOverlayView(
                color: theme.sakuraPetalColor,
                opacity: 0.20 * visibilityBoost,
                amplitude: 0.2,
                frequency: 1.65,
                verticalOffset: 0.78,
                bottomFade: 0.45,
                petalDensity: 0.66,
                driftDuration: 22,
                crestColor: theme.sakuraIvoryColor,
                crestOpacity: 0.16 * visibilityBoost,
                crestWidth: 1.15
            )
            .frame(height: 150)

            SakuraBranchShape(
                amplitude: 0.08,
                frequency: 1.05,
                phase: 0,
                verticalOffset: 0.74,
                twigDensity: 0.42
            )
            .stroke(
                theme.sakuraLeafColor.opacity(0.24 * visibilityBoost),
                style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
            )
            .frame(height: 145)

            SakuraBranchShape(
                amplitude: 0.07,
                frequency: 1.36,
                phase: CGFloat.pi * 0.43,
                verticalOffset: 0.79,
                twigDensity: 0.35
            )
            .stroke(
                theme.sakuraPetalColor.opacity(0.15 * visibilityBoost),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
            )
            .frame(height: 145)
            .blur(radius: 0.2)

            SakuraPetalDriftView(
                intensity: 0.75,
                darkModeBoost: colorScheme == .dark ? 1.25 : 1.0,
                petalCount: 16,
                speed: 16,
                petalColor: theme.sakuraPetalColor
            )

            LinearGradient(
                colors: [
                    (colorScheme == .dark ? theme.sakuraIvoryColor : theme.sakuraPetalColor).opacity(0.18),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sakura Sheet Background

/// Lightest single-layer blossom background for sheets.
struct SakuraSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.25 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            SakuraWaveOverlayView(
                color: theme.sakuraPetalColor,
                opacity: 0.15 * visibilityBoost,
                amplitude: 0.17,
                frequency: 1.1,
                verticalOffset: 0.42,
                bottomFade: 0.55,
                petalDensity: 0.5,
                driftDuration: 23,
                crestColor: theme.sakuraIvoryColor,
                crestOpacity: 0.16 * visibilityBoost,
                crestWidth: 1.2
            )
            .frame(height: 140)

            SakuraBranchShape(
                amplitude: 0.06,
                frequency: 0.9,
                phase: 0,
                verticalOffset: 0.73,
                twigDensity: 0.3
            )
            .stroke(
                theme.sakuraLeafColor.opacity(0.18 * visibilityBoost),
                style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
            )
            .frame(height: 130)

            SakuraBranchShape(
                amplitude: 0.05,
                frequency: 1.28,
                phase: CGFloat.pi * 0.38,
                verticalOffset: 0.78,
                twigDensity: 0.24
            )
            .stroke(
                theme.sakuraPetalColor.opacity(0.12 * visibilityBoost),
                style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)
            )
            .frame(height: 128)
            .blur(radius: 0.15)

            SakuraPetalDriftView(
                intensity: 0.48,
                darkModeBoost: colorScheme == .dark ? 1.2 : 1.0,
                petalCount: 10,
                speed: 18,
                petalColor: theme.sakuraPetalColor
            )

            LinearGradient(
                colors: [
                    .clear,
                    (colorScheme == .dark ? theme.sakuraIvoryColor : theme.sakuraPetalColor).opacity(0.16)
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("Sakura Tab") {
    SakuraTabWaveBackground()
        .environment(\.appTheme, .sakuraCalm)
}

#Preview("Sakura Detail") {
    SakuraDetailWaveBackground()
        .environment(\.appTheme, .sakuraCalm)
}

#Preview("Sakura Sheet") {
    SakuraSheetWaveBackground()
        .environment(\.appTheme, .sakuraCalm)
}
