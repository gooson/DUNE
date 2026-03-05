import SwiftUI
import UIKit

// MARK: - Shanks Motif Overlay

/// Pirate flag motif silhouette used across Shanks backgrounds.
///
/// The shape uses an even-odd fill to carve eye/nose holes from the skull.
struct ShanksPirateFlagSigil: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let skullWidth = size * 0.56
        let skullHeight = size * 0.50
        let skullRect = CGRect(
            x: center.x - skullWidth / 2,
            y: center.y - size * 0.30,
            width: skullWidth,
            height: skullHeight
        )

        let jawRect = CGRect(
            x: center.x - skullWidth * 0.22,
            y: skullRect.maxY - size * 0.06,
            width: skullWidth * 0.44,
            height: size * 0.15
        )

        let eyeSize = size * 0.085
        let leftEye = CGRect(
            x: center.x - skullWidth * 0.17 - eyeSize / 2,
            y: skullRect.minY + skullHeight * 0.35,
            width: eyeSize,
            height: eyeSize
        )
        let rightEye = CGRect(
            x: center.x + skullWidth * 0.17 - eyeSize / 2,
            y: skullRect.minY + skullHeight * 0.35,
            width: eyeSize,
            height: eyeSize
        )

        let noseTop = CGPoint(x: center.x, y: skullRect.minY + skullHeight * 0.52)
        let noseLeft = CGPoint(x: center.x - size * 0.045, y: skullRect.minY + skullHeight * 0.63)
        let noseRight = CGPoint(x: center.x + size * 0.045, y: skullRect.minY + skullHeight * 0.63)

        let boneWidth = size * 0.13
        let boneLength = size * 0.98
        let boneCenterY = center.y + size * 0.21

        var path = Path()

        func addBone(angle: CGFloat) {
            let shaftRect = CGRect(
                x: -boneLength / 2,
                y: -boneWidth / 2,
                width: boneLength,
                height: boneWidth
            )
            let knobDiameter = boneWidth * 0.70
            let startKnobRect = CGRect(
                x: shaftRect.minX - knobDiameter * 0.35,
                y: -knobDiameter / 2,
                width: knobDiameter,
                height: knobDiameter
            )
            let endKnobRect = CGRect(
                x: shaftRect.maxX - knobDiameter * 0.65,
                y: -knobDiameter / 2,
                width: knobDiameter,
                height: knobDiameter
            )

            let transform = CGAffineTransform(rotationAngle: angle)
                .concatenating(CGAffineTransform(translationX: center.x, y: boneCenterY))

            path.addPath(
                Path(
                    roundedRect: shaftRect,
                    cornerSize: CGSize(width: boneWidth / 2, height: boneWidth / 2)
                ),
                transform: transform
            )
            path.addPath(Path(ellipseIn: startKnobRect), transform: transform)
            path.addPath(Path(ellipseIn: endKnobRect), transform: transform)
        }

        addBone(angle: .pi / 4.8)
        addBone(angle: -.pi / 4.8)

        path.addEllipse(in: skullRect)
        path.addPath(
            Path(
                roundedRect: jawRect,
                cornerSize: CGSize(width: size * 0.03, height: size * 0.03)
            )
        )

        // Cut-outs for skull features (rendered with even-odd fill).
        path.addEllipse(in: leftEye)
        path.addEllipse(in: rightEye)
        path.move(to: noseTop)
        path.addLine(to: noseLeft)
        path.addLine(to: noseRight)
        path.closeSubpath()

        return path
    }
}

private struct ShanksFlagTextureView: View {
    let opacity: Double

    private static let textureImage: UIImage = {
        let size = CGSize(width: 380, height: 230)
        let step: CGFloat = 4
        let columns = Int(size.width / step)
        let rows = Int(size.height / step)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            for row in 0..<rows {
                for col in 0..<columns {
                    let seed = Double(row * 541 + col * 173)
                    let noise = sin(seed * 0.071) * sin(seed * 0.041) * sin(seed * 0.019)
                    let alpha = abs(noise) * 0.10
                    context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
                    context.fill(
                        CGRect(
                            x: CGFloat(col) * step,
                            y: CGFloat(row) * step,
                            width: step,
                            height: step
                        )
                    )
                }
            }
        }
    }()

    var body: some View {
        Image(uiImage: Self.textureImage)
            .resizable()
            .interpolation(.none)
            .opacity(opacity)
            .blendMode(.softLight)
            .allowsHitTesting(false)
    }
}

private struct ShanksPirateFlagOverlay: View {
    var opacity: Double
    var width: CGFloat
    var topPadding: CGFloat

    @State private var sway: CGFloat = -0.08
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var darkBoost: Double {
        colorScheme == .dark ? 1.18 : 1.0
    }

    var body: some View {
        ShanksPirateFlagSigil()
            .fill(
                theme.sandColor.opacity(opacity * darkBoost),
                style: FillStyle(eoFill: true)
            )
            .frame(width: width, height: width)
            .rotationEffect(.degrees(-14 + Double(sway) * 8))
            .overlay {
                ShanksPirateFlagSigil()
                    .stroke(
                        theme.bronzeColor.opacity(opacity * 0.52 * darkBoost),
                        lineWidth: 0.9
                    )
                    .frame(width: width, height: width)
                    .rotationEffect(.degrees(-14 + Double(sway) * 8))
            }
            .padding(.top, topPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
            .task {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 6.8).repeatForever(autoreverses: true)) {
                    sway = 0.08
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                Task { @MainActor in
                    sway = -0.08
                    withAnimation(.easeInOut(duration: 6.8).repeatForever(autoreverses: true)) {
                        sway = 0.08
                    }
                }
            }
    }
}

private struct ShanksHakiStreakOverlay: View {
    var opacity: Double
    var blur: CGFloat
    var width: CGFloat
    var topPadding: CGFloat

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.shanksGlowColor.opacity(opacity),
                            theme.bronzeColor.opacity(opacity * 0.7),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 2)
                .rotationEffect(.degrees(-17))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.bronzeColor.opacity(opacity * 0.74),
                            theme.shanksCoreColor.opacity(opacity * 0.62),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * 0.76, height: 2)
                .rotationEffect(.degrees(-11))
        }
        .blur(radius: blur)
        .padding(.top, topPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
    }
}

// MARK: - Shanks Tab Background

/// Multi-layer parallax crimson wave background for tab root screens.
///
/// Layers (back to front):
/// 1. **Deep** — slow, dark waves (pirate flag silhouette horizon)
/// 2. **Core** — crimson mid-layer with gold crest highlights
/// 3. **Glow** — bright scarlet foreground with shimmer
///
/// Reuses `DesertDuneOverlayView` for the wave shape, parameterized with
/// Shanks Red Hair Pirates theme colors: deep navy, crimson, and gold.
struct ShanksTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2   // Battle intensity
        case .today:    1.0
        case .wellness: 0.8   // Calm seas
        case .life:     0.6   // Harbor stillness
        }
    }

    private var darkBoost: Double {
        colorScheme == .dark ? 1.12 : 1.0
    }

    private var resolvedColor: Color {
        isWeatherActive ? atmosphere.waveColor : color
    }

    var body: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * darkBoost

        ZStack(alignment: .top) {
            // Layer 1: Deep — broad, dark horizon (pirate flag backdrop)
            DesertDuneOverlayView(
                color: theme.shanksDeepColor,
                opacity: 0.10 * opacityScale,
                amplitude: 0.042 * scale,
                frequency: 0.78,
                verticalOffset: 0.34,
                bottomFade: 0.52,
                skewness: 0.22,
                skewOffset: .pi / 5,
                driftDuration: 20,
                crestColor: theme.shanksCoreColor,
                crestOpacity: 0.10 * opacityScale,
                crestWidth: 0.8
            )
            .frame(height: 200)

            // Layer 2: Core — crimson mid-layer with gold crest
            DesertDuneOverlayView(
                color: theme.shanksCoreColor,
                opacity: 0.16 * opacityScale,
                amplitude: 0.075 * scale,
                frequency: 1.25,
                verticalOffset: 0.50,
                bottomFade: 0.46,
                skewness: 0.18,
                skewOffset: .pi / 4,
                driftDuration: 14,
                crestColor: theme.bronzeColor,
                crestOpacity: 0.18 * opacityScale,
                crestWidth: 1.2
            )
            .frame(height: 200)

            // Layer 3: Glow — bright scarlet foreground
            DesertDuneOverlayView(
                color: resolvedColor,
                opacity: 0.20 * opacityScale,
                amplitude: 0.094 * scale,
                frequency: 1.6,
                verticalOffset: 0.60,
                bottomFade: 0.42,
                skewness: 0.12,
                skewOffset: .pi / 3,
                driftDuration: 11,
                showShimmer: false,
                crestColor: theme.shanksGlowColor,
                crestOpacity: 0.24 * opacityScale,
                crestWidth: 1.5
            )
            .frame(height: 200)

            // Background gradient
            LinearGradient(
                colors: shanksGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            ShanksFlagTextureView(opacity: colorScheme == .dark ? 0.16 : 0.12)
            ShanksPirateFlagOverlay(
                opacity: colorScheme == .dark ? 0.14 : 0.10,
                width: 170,
                topPadding: 10
            )
            ShanksHakiStreakOverlay(
                opacity: colorScheme == .dark ? 0.36 : 0.28,
                blur: 0.4,
                width: 160,
                topPadding: 22
            )
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }

    private var shanksGradientColors: [Color] {
        if isWeatherActive {
            return atmosphere.gradientColors
        }
        let darkAlpha = colorScheme == .dark
        return [
            theme.shanksDeepColor.opacity(darkAlpha ? 0.36 : 0.28),
            theme.shanksCoreColor.opacity(darkAlpha ? 0.22 : 0.16),
            theme.shanksGlowColor.opacity(darkAlpha ? 0.12 : 0.08),
            .clear
        ]
    }
}

// MARK: - Shanks Detail Background

/// Subtler two-layer crimson wave for push-destination detail screens.
struct ShanksDetailWaveBackground: View {
    @Environment(\.waveColor) private var color
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            // Core crimson layer
            DesertDuneOverlayView(
                color: theme.shanksCoreColor,
                opacity: 0.10,
                amplitude: 0.038,
                frequency: 1.0,
                verticalOffset: 0.44,
                bottomFade: 0.54,
                skewness: 0.18,
                driftDuration: 16,
                crestColor: theme.bronzeColor,
                crestOpacity: 0.14,
                crestWidth: 0.9
            )
            .frame(height: 150)

            // Scarlet foreground
            DesertDuneOverlayView(
                color: color,
                opacity: 0.15,
                amplitude: 0.060,
                frequency: 1.5,
                verticalOffset: 0.54,
                bottomFade: 0.48,
                skewness: 0.14,
                driftDuration: 12,
                crestColor: theme.shanksGlowColor,
                crestOpacity: 0.20,
                crestWidth: 1.2
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    theme.shanksDeepColor.opacity(colorScheme == .dark ? 0.26 : 0.18),
                    theme.shanksCoreColor.opacity(colorScheme == .dark ? 0.14 : 0.10),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            ShanksFlagTextureView(opacity: colorScheme == .dark ? 0.10 : 0.07)
            ShanksPirateFlagOverlay(
                opacity: colorScheme == .dark ? 0.08 : 0.06,
                width: 132,
                topPadding: 8
            )
            ShanksHakiStreakOverlay(
                opacity: colorScheme == .dark ? 0.24 : 0.18,
                blur: 0.6,
                width: 122,
                topPadding: 20
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Shanks Sheet Background

/// Lightest single-layer crimson wave for sheet/modal presentations.
struct ShanksSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            DesertDuneOverlayView(
                color: theme.shanksCoreColor,
                opacity: 0.08,
                amplitude: 0.032,
                frequency: 0.9,
                verticalOffset: 0.48,
                bottomFade: 0.52,
                skewness: 0.16,
                driftDuration: 18,
                crestColor: theme.bronzeColor,
                crestOpacity: 0.12,
                crestWidth: 0.9
            )
            .frame(height: 120)

            LinearGradient(
                colors: [
                    theme.shanksDeepColor.opacity(colorScheme == .dark ? 0.20 : 0.14),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )

            ShanksFlagTextureView(opacity: colorScheme == .dark ? 0.08 : 0.05)
            ShanksPirateFlagOverlay(
                opacity: colorScheme == .dark ? 0.06 : 0.04,
                width: 110,
                topPadding: 6
            )
        }
        .ignoresSafeArea()
    }
}
