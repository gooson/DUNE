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
        colorScheme == .dark ? 1.25 : 1.0
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
            // Layer 1: Soft ivory haze
            SakuraWaveOverlayView(
                color: theme.sakuraIvoryColor,
                opacity: 0.12 * opacityScale,
                amplitude: 0.23 * scale,
                frequency: 0.9,
                verticalOffset: 0.52,
                bottomFade: 0.55,
                petalDensity: 0.22,
                driftDuration: 34,
                crestColor: theme.sakuraPetalColor,
                crestOpacity: 0.08 * opacityScale,
                crestWidth: 1.0
            )
            .frame(height: 170)

            // Layer 2: Main petal band
            SakuraWaveOverlayView(
                color: theme.sakuraPetalColor,
                opacity: 0.24 * opacityScale,
                amplitude: 0.32 * scale,
                frequency: 1.55,
                verticalOffset: 0.78,
                bottomFade: 0.42,
                petalDensity: 0.70,
                driftDuration: 25,
                showTexture: true,
                textureOpacity: colorScheme == .dark ? 0.012 : 0.026,
                crestColor: theme.sakuraIvoryColor,
                crestOpacity: 0.15 * opacityScale,
                crestWidth: 1.1
            )
            .frame(height: 185)

            // Layer 3: Deep green anchor
            SakuraWaveOverlayView(
                color: theme.sakuraLeafColor,
                opacity: 0.30 * opacityScale,
                amplitude: 0.28 * scale,
                frequency: 2.25,
                verticalOffset: 0.88,
                bottomFade: 0.38,
                petalDensity: 0.42,
                driftDuration: 18,
                crestColor: theme.sakuraPetalColor,
                crestOpacity: 0.22 * opacityScale,
                crestWidth: 1.2
            )
            .frame(height: 190)

            LinearGradient(
                colors: sakuraGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        theme.sakuraIvoryColor.opacity(0.16),
                        theme.sakuraPetalColor.opacity(0.08),
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
                theme.sakuraIvoryColor.opacity(DS.Opacity.light),
                theme.sakuraPetalColor.opacity(DS.Opacity.subtle),
                theme.sakuraLeafColor.opacity(DS.Opacity.subtle),
                .clear
            ]
        }
        return [
            theme.sakuraPetalColor.opacity(DS.Opacity.medium),
            theme.sakuraIvoryColor.opacity(DS.Opacity.light),
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
        colorScheme == .dark ? 1.2 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            SakuraWaveOverlayView(
                color: theme.sakuraIvoryColor,
                opacity: 0.08 * visibilityBoost,
                amplitude: 0.20,
                frequency: 1.2,
                verticalOffset: 0.46,
                bottomFade: 0.52,
                petalDensity: 0.24,
                driftDuration: 24,
                crestColor: theme.sakuraPetalColor,
                crestOpacity: 0.09 * visibilityBoost,
                crestWidth: 1.0
            )
            .frame(height: 150)

            SakuraWaveOverlayView(
                color: theme.sakuraLeafColor,
                opacity: 0.16 * visibilityBoost,
                amplitude: 0.24,
                frequency: 1.9,
                verticalOffset: 0.83,
                bottomFade: 0.45,
                petalDensity: 0.3,
                driftDuration: 19,
                crestColor: theme.sakuraPetalColor,
                crestOpacity: 0.14 * visibilityBoost,
                crestWidth: 1.0
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    (colorScheme == .dark ? theme.sakuraIvoryColor : theme.sakuraPetalColor).opacity(DS.Opacity.light),
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
        colorScheme == .dark ? 1.15 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            SakuraWaveOverlayView(
                color: theme.sakuraPetalColor,
                opacity: 0.11 * visibilityBoost,
                amplitude: 0.2,
                frequency: 1.1,
                verticalOffset: 0.42,
                bottomFade: 0.55,
                petalDensity: 0.25,
                driftDuration: 20,
                crestColor: theme.sakuraIvoryColor,
                crestOpacity: 0.12 * visibilityBoost,
                crestWidth: 1.2
            )
            .frame(height: 140)

            LinearGradient(
                colors: [
                    .clear,
                    (colorScheme == .dark ? theme.sakuraIvoryColor : theme.sakuraPetalColor).opacity(DS.Opacity.light)
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
