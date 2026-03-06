import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Hanok Motif Shape

/// Palace-style roof-end medallion inspired by traditional wa-dang (기와 막새).
/// Used as a subtle decorative motif to make the Hanok theme immediately recognizable.
struct HanokRoofTileSealShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerDiameter = size * 0.78
        let innerDiameter = size * 0.28

        let outerRect = CGRect(
            x: center.x - outerDiameter / 2,
            y: center.y - outerDiameter / 2,
            width: outerDiameter,
            height: outerDiameter
        )
        let innerRect = CGRect(
            x: center.x - innerDiameter / 2,
            y: center.y - innerDiameter / 2,
            width: innerDiameter,
            height: innerDiameter
        )

        var path = Path()
        path.addEllipse(in: outerRect)
        path.addEllipse(in: innerRect)

        let petalRect = CGRect(
            x: -size * 0.085,
            y: -size * 0.31,
            width: size * 0.17,
            height: size * 0.25
        )

        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            let transform = CGAffineTransform(rotationAngle: angle)
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
            path.addPath(
                RoundedRectangle(cornerRadius: size * 0.07, style: .continuous).path(in: petalRect),
                transform: transform
            )
        }

        let diamondRadius = size * 0.14
        path.move(to: CGPoint(x: center.x, y: center.y - diamondRadius))
        path.addLine(to: CGPoint(x: center.x + diamondRadius, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + diamondRadius))
        path.addLine(to: CGPoint(x: center.x - diamondRadius, y: center.y))
        path.closeSubpath()

        return path
    }
}

/// Broad mountain ridge silhouette placed behind the pavilion motif.
/// A gentle animated ridge shift keeps the scene from feeling static.
struct HanokMountainBackdropShape: Shape {
    var ridgeShift: CGFloat = 0

    var animatableData: CGFloat {
        get { ridgeShift }
        set { ridgeShift = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let shift = ridgeShift * rect.width
        let baseY = rect.height * 0.94

        var path = Path()
        path.move(to: CGPoint(x: 0, y: baseY))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.54),
            control1: CGPoint(x: rect.width * 0.05 + shift * 0.10, y: rect.height * 0.78),
            control2: CGPoint(x: rect.width * 0.13 + shift * 0.16, y: rect.height * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.52, y: rect.height * 0.22),
            control1: CGPoint(x: rect.width * 0.30 + shift * 0.18, y: rect.height * 0.44),
            control2: CGPoint(x: rect.width * 0.42 + shift * 0.22, y: rect.height * 0.14)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.48),
            control1: CGPoint(x: rect.width * 0.61 + shift * 0.18, y: rect.height * 0.26),
            control2: CGPoint(x: rect.width * 0.71 + shift * 0.12, y: rect.height * 0.36)
        )
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.70),
            control1: CGPoint(x: rect.width * 0.85 + shift * 0.08, y: rect.height * 0.56),
            control2: CGPoint(x: rect.width * 0.93 + shift * 0.08, y: rect.height * 0.62)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

/// Gyeonghoeru-inspired pavilion silhouette with raised platform and layered rooflines.
/// The goal is recognizability, not literal architectural reconstruction.
struct HanokPavilionSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        var path = Path()
        let corner = CGSize(width: rect.height * 0.02, height: rect.height * 0.02)

        let platformRect = CGRect(
            x: rect.minX + rect.width * 0.08,
            y: rect.minY + rect.height * 0.82,
            width: rect.width * 0.84,
            height: rect.height * 0.10
        )
        path.addRoundedRect(in: platformRect, cornerSize: corner, style: .continuous)

        let terraceRect = CGRect(
            x: rect.minX + rect.width * 0.12,
            y: rect.minY + rect.height * 0.74,
            width: rect.width * 0.76,
            height: rect.height * 0.05
        )
        path.addRoundedRect(in: terraceRect, cornerSize: corner, style: .continuous)

        let balustradeRect = CGRect(
            x: rect.minX + rect.width * 0.14,
            y: rect.minY + rect.height * 0.58,
            width: rect.width * 0.72,
            height: rect.height * 0.04
        )
        path.addRoundedRect(in: balustradeRect, cornerSize: corner, style: .continuous)

        let beamRect = CGRect(
            x: rect.minX + rect.width * 0.12,
            y: rect.minY + rect.height * 0.44,
            width: rect.width * 0.76,
            height: rect.height * 0.04
        )
        path.addRoundedRect(in: beamRect, cornerSize: corner, style: .continuous)

        let columnWidth = rect.width * 0.052
        let columnHeight = rect.height * 0.29
        for anchor in [0.18, 0.32, 0.46, 0.60, 0.74, 0.86] {
            let columnRect = CGRect(
                x: rect.minX + rect.width * anchor - columnWidth / 2,
                y: rect.minY + rect.height * 0.48,
                width: columnWidth,
                height: columnHeight
            )
            path.addRoundedRect(in: columnRect, cornerSize: corner, style: .continuous)
        }

        let stairRect = CGRect(
            x: rect.minX + rect.width * 0.44,
            y: rect.minY + rect.height * 0.78,
            width: rect.width * 0.12,
            height: rect.height * 0.08
        )
        path.addRoundedRect(in: stairRect, cornerSize: corner, style: .continuous)

        var lowerRoof = Path()
        lowerRoof.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.40))
        lowerRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.22),
            control: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.17)
        )
        lowerRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.96, y: rect.minY + rect.height * 0.40),
            control: CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.17)
        )
        lowerRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.47),
            control: CGPoint(x: rect.minX + rect.width * 0.93, y: rect.minY + rect.height * 0.46)
        )
        lowerRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.31),
            control: CGPoint(x: rect.minX + rect.width * 0.73, y: rect.minY + rect.height * 0.31)
        )
        lowerRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.47),
            control: CGPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.31)
        )
        lowerRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.40),
            control: CGPoint(x: rect.minX + rect.width * 0.07, y: rect.minY + rect.height * 0.46)
        )
        lowerRoof.closeSubpath()
        path.addPath(lowerRoof)

        let upperHallRect = CGRect(
            x: rect.minX + rect.width * 0.42,
            y: rect.minY + rect.height * 0.27,
            width: rect.width * 0.16,
            height: rect.height * 0.12
        )
        path.addRoundedRect(in: upperHallRect, cornerSize: corner, style: .continuous)

        var upperRoof = Path()
        upperRoof.move(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.28))
        upperRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.12),
            control: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.11)
        )
        upperRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.28),
            control: CGPoint(x: rect.minX + rect.width * 0.61, y: rect.minY + rect.height * 0.11)
        )
        upperRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.33),
            control: CGPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.32)
        )
        upperRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.33),
            control: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.23)
        )
        upperRoof.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.28),
            control: CGPoint(x: rect.minX + rect.width * 0.31, y: rect.minY + rect.height * 0.32)
        )
        upperRoof.closeSubpath()
        path.addPath(upperRoof)

        let finialRect = CGRect(
            x: rect.minX + rect.width * 0.485,
            y: rect.minY + rect.height * 0.08,
            width: rect.width * 0.03,
            height: rect.height * 0.08
        )
        path.addRoundedRect(in: finialRect, cornerSize: corner, style: .continuous)

        return path
    }
}

private struct HanokRoofSealOverlay: View {
    var opacity: Double
    var size: CGFloat
    var topPadding: CGFloat
    var trailingPadding: CGFloat

    @State private var drift: CGFloat = -0.06
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var lineHeight: CGFloat { max(1.3, size * 0.07) }
    private var secondaryLineHeight: CGFloat { max(1.0, size * 0.05) }

    private var strokeGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.sandColor.opacity(opacity * (colorScheme == .dark ? 0.95 : 0.84)),
                theme.scoreExcellent.opacity(opacity * 0.62),
                theme.hanokDeepColor.opacity(opacity * 0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 5) {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.hanokDeepColor.opacity(opacity * 0.16),
                                theme.sandColor.opacity(opacity * 0.34),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 1.9, height: lineHeight)
                    .rotationEffect(.degrees(-8))

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.scoreExcellent.opacity(opacity * 0.18),
                                theme.hanokMistColor.opacity(opacity * 0.28),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 1.18, height: secondaryLineHeight)
                    .rotationEffect(.degrees(-8))
                    .padding(.trailing, size * 0.16)
            }
            .padding(.top, topPadding + size * 0.26)
            .padding(.trailing, trailingPadding + size * 0.40)

            HanokRoofTileSealShape()
                .stroke(
                    strokeGradient,
                    style: StrokeStyle(
                        lineWidth: max(1.1, size * 0.045),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .background {
                    Circle()
                        .fill(theme.cardBackground.opacity(opacity * 0.20))
                        .frame(width: size * 0.82, height: size * 0.82)
                        .blur(radius: size * 0.10)
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-10 + Double(drift) * 12))
                .shadow(
                    color: theme.hanokDeepColor.opacity(opacity * 0.18),
                    radius: size * 0.12,
                    y: size * 0.05
                )
                .padding(.top, topPadding)
                .padding(.trailing, trailingPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
        .task(id: reduceMotion) {
            drift = -0.06
            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 6.4).repeatForever(autoreverses: true)) {
                drift = 0.06
            }
        }
    }
}

private struct HanokPavilionLandscapeOverlay: View {
    var opacity: Double
    var width: CGFloat
    var topPadding: CGFloat
    var leadingPadding: CGFloat

    @State private var ridgeShift: CGFloat = -0.035
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var mountainGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.hanokMistColor.opacity(opacity * (colorScheme == .dark ? 0.18 : 0.26)),
                theme.hanokMidColor.opacity(opacity * (colorScheme == .dark ? 0.30 : 0.40)),
                theme.hanokDeepColor.opacity(opacity * (colorScheme == .dark ? 0.26 : 0.34))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var pavilionGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.hanokDeepColor.opacity(opacity * (colorScheme == .dark ? 0.74 : 0.82)),
                theme.hanokMidColor.opacity(opacity * (colorScheme == .dark ? 0.60 : 0.68))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HanokMountainBackdropShape(ridgeShift: ridgeShift)
                .fill(mountainGradient)
                .frame(width: width * 1.24, height: width * 0.58)
                .offset(x: width * 0.02, y: width * 0.02)

            HanokMountainBackdropShape(ridgeShift: -ridgeShift * 0.55)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.hanokMistColor.opacity(opacity * (colorScheme == .dark ? 0.10 : 0.16)),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.98, height: width * 0.38)
                .offset(x: width * 0.20, y: width * 0.11)
                .blur(radius: width * 0.014)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.sandColor.opacity(opacity * (colorScheme == .dark ? 0.04 : 0.10)),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.84, height: width * 0.14)
                .offset(x: width * 0.26, y: width * 0.22)
                .blur(radius: width * 0.025)

            HanokPavilionSilhouetteShape()
                .fill(pavilionGradient)
                .overlay {
                    HanokPavilionSilhouetteShape()
                        .stroke(
                            theme.sandColor.opacity(opacity * (colorScheme == .dark ? 0.10 : 0.18)),
                            style: StrokeStyle(
                                lineWidth: max(0.8, width * 0.008),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .blendMode(.screen)
                }
                .frame(width: width, height: width * 0.82)
                .offset(x: width * 0.16, y: width * 0.12)
                .shadow(
                    color: theme.hanokDeepColor.opacity(opacity * 0.18),
                    radius: width * 0.04,
                    y: width * 0.02
                )
        }
        .frame(width: width * 1.42, height: width * 0.84, alignment: .bottomLeading)
        .padding(.top, topPadding)
        .padding(.leading, leadingPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .task(id: reduceMotion) {
            ridgeShift = -0.035
            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 9.2).repeatForever(autoreverses: true)) {
                ridgeShift = 0.035
            }
        }
    }
}

// MARK: - Hanok Wave Overlay View

/// Single animated hanok eave layer with gradient fade, optional hanji texture,
/// and wind-sway breath modulation for organic movement.
struct HanokWaveOverlayView: View {
    var color: Color
    var opacity: Double = 0.10
    var amplitude: CGFloat = 0.05
    var frequency: CGFloat = 1.5
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0.4
    var uplift: CGFloat = 0.2
    var tileRipple: CGFloat = 0
    var tileFrequency: CGFloat = 8.0
    var driftDuration: Double = 8
    var showHanji: Bool = false
    var hanjiOpacity: Double = 0.03
    var crestColor: Color? = nil
    var crestOpacity: Double = 0.18
    var crestWidth: CGFloat = 1.2
    /// Wind-sway breath intensity (0 = none, 0.15 = strong).
    /// Modulates amplitude sinusoidally for organic wind feel.
    var breathIntensity: CGFloat = 0

    @State private var phase: CGFloat = 0
    @State private var breathPhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Harmonic multipliers (uplift uses 2nd harmonic + 0.5 swell) need
    /// LCM = 10 turns for seamless loop.
    private static let phaseLoopTurns: CGFloat = 10
    private var phaseTarget: CGFloat { 2 * .pi * Self.phaseLoopTurns }
    private var phaseDuration: Double { driftDuration * Double(Self.phaseLoopTurns) }

    /// Breath cycle duration — slightly offset from drift for organic feel.
    private var breathDuration: Double { driftDuration * 1.3 }

    /// Current amplitude with breath modulation applied.
    private var modulatedAmplitude: CGFloat {
        guard breathIntensity > 0 else { return amplitude }
        return amplitude * (1 + breathIntensity * sin(breathPhase))
    }

    /// Shared shape instance for fill and crest strokes.
    private var eaveShape: HanokEaveShape {
        HanokEaveShape(
            amplitude: modulatedAmplitude,
            frequency: frequency,
            phase: phase,
            verticalOffset: verticalOffset,
            uplift: uplift,
            tileRipple: tileRipple,
            tileFrequency: tileFrequency
        )
    }

    private func restartAnimations() {
        phase = 0
        breathPhase = 0

        guard !reduceMotion else { return }

        if driftDuration > 0 {
            withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
                phase = phaseTarget
            }
        }

        if breathIntensity > 0 {
            withAnimation(.easeInOut(duration: breathDuration).repeatForever(autoreverses: true)) {
                breathPhase = .pi
            }
        }
    }

    var body: some View {
        let shape = eaveShape
        ZStack {
            shape
                .fill(color.opacity(opacity))
                .bottomFadeMask(bottomFade)

            if let crestColor {
                ZStack {
                    // Wide translucent crest band.
                    shape
                        .stroke(
                            crestColor.opacity(crestOpacity * 0.48),
                            style: StrokeStyle(lineWidth: crestWidth * 2.6, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 1.1)

                    // Core crest highlight line.
                    shape
                        .stroke(
                            crestColor.opacity(crestOpacity),
                            style: StrokeStyle(lineWidth: crestWidth, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 0.25)
                }
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.87)
                    )
                )
                .blendMode(.screen)
            }

            if showHanji {
                HanjiTextureView(opacity: hanjiOpacity)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            restartAnimations()
        }
        .onChange(of: breathIntensity) { _, _ in
            restartAnimations()
        }
        .onChange(of: reduceMotion) { _, _ in
            restartAnimations()
        }
    }
}

// MARK: - Hanji Texture Overlay

/// Procedural hanji (한지) paper fiber texture pre-rendered to a UIImage.
/// Simulates the subtle fiber patterns of traditional Korean paper.
/// Rendered once as a static constant — zero per-frame computation.
/// Uses warm ivory and cool slate fibers to preserve hanji materiality
/// while still feeling at home in the slate-toned hanok palette.
private struct HanjiTextureView: View {
    let opacity: Double

    /// Pre-rendered hanji texture. Computed once at first access.
    /// Uses layered sine products to simulate paper fiber directionality.
    private static let hanjiImage: UIImage = {
        let size = CGSize(width: 400, height: 200)
        let step: CGFloat = 3
        let cols = Int(size.width / step)
        let rows = Int(size.height / step)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            for row in 0..<rows {
                for col in 0..<cols {
                    let seed = Double(row * 853 + col * 149)
                    // Directional fiber pattern — horizontal bias for hanji
                    let horizontal = sin(seed * 0.09) * sin(seed * 0.061)
                    let vertical = sin(seed * 0.043) * sin(seed * 0.029) * 0.4
                    let noise = horizontal + vertical
                    let alpha = abs(noise) * 0.10
                    let warmFiber = UIColor(
                        red: 0.91,
                        green: 0.87,
                        blue: 0.78,
                        alpha: alpha * 0.84
                    )
                    let coolFiber = UIColor(
                        red: 0.47,
                        green: 0.56,
                        blue: 0.58,
                        alpha: alpha * 0.34
                    )
                    cgContext.setFillColor((noise >= 0 ? warmFiber : coolFiber).cgColor)
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
        Image(uiImage: Self.hanjiImage)
            .resizable()
            .interpolation(.none)
            .opacity(opacity)
            .blendMode(.softLight)
            .allowsHitTesting(false)
    }
}

// MARK: - Hanok Tab Background

/// Multi-layer parallax hanok rooftop background for tab root screens.
///
/// Layers (back to front):
/// 1. **Far** — distant giwa rooftops (기와), lightest, slow drift + gentle sway
/// 2. **Mid** — cheoma eave curves (처마), moderate density + medium sway
/// 3. **Near** — foreground eave with tile texture, darkest + strongest sway
///
/// Wind-sway breath modulation creates organic wind feel across layers.
/// Includes hanji paper texture overlay on near layer.
struct HanokTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    /// Dark mode needs a small visibility lift for jade tones.
    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.3 : 1.0
    }

    /// Scale factor based on tab preset character.
    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2   // Active courtyard
        case .today:    1.0
        case .wellness: 0.8   // Tranquil garden
        case .life:     0.6   // Distant village
        }
    }

    var body: some View {
        let scale = intensityScale
        let opacityScale = Double(scale) * visibilityBoost

        ZStack(alignment: .top) {
            // Layer 1: Far — distant giwa rooftops (gentle sway)
            HanokWaveOverlayView(
                color: theme.hanokMistColor,
                opacity: 0.11 * opacityScale,
                amplitude: 0.042 * scale,
                frequency: 0.76,
                verticalOffset: 0.40,
                bottomFade: 0.5,
                uplift: 0.15,
                driftDuration: 25,
                crestColor: theme.sandColor,
                crestOpacity: 0.10 * opacityScale,
                crestWidth: 0.9,
                breathIntensity: 0.05
            )
            .frame(height: 160)

            // Layer 2: Mid — cheoma eave curves (medium sway)
            HanokWaveOverlayView(
                color: theme.hanokMidColor,
                opacity: 0.26 * opacityScale,
                amplitude: 0.058 * scale,
                frequency: 1.35,
                verticalOffset: 0.55,
                bottomFade: 0.4,
                uplift: 0.25,
                tileRipple: 0.05,
                driftDuration: 20,
                crestColor: theme.sandColor,
                crestOpacity: 0.16 * opacityScale,
                crestWidth: 1.02,
                breathIntensity: 0.08
            )
            .frame(height: 170)

            // Layer 3: Near — foreground eave with tile texture (strong sway, jade crest)
            HanokWaveOverlayView(
                color: theme.hanokDeepColor,
                opacity: 0.70 * opacityScale,
                amplitude: 0.052 * scale,
                frequency: 2.0,
                verticalOffset: 0.60,
                bottomFade: 0.4,
                uplift: 0.30,
                tileRipple: 0.10,
                tileFrequency: 10.0,
                driftDuration: 16,
                showHanji: true,
                hanjiOpacity: colorScheme == .dark ? 0.016 : 0.034,
                crestColor: theme.sandColor,
                crestOpacity: 0.42 * opacityScale,
                crestWidth: 1.12,
                breathIntensity: 0.12
            )
            .frame(height: 180)

            // Background gradient
            LinearGradient(
                colors: hanokGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        theme.hanokMistColor.opacity(0.18),
                        theme.hanokMidColor.opacity(0.08),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: DS.Gradient.tabBackgroundEnd
                )
            }

            HanokPavilionLandscapeOverlay(
                opacity: colorScheme == .dark ? 0.64 : 0.76,
                width: 170 + (26 * scale),
                topPadding: 34,
                leadingPadding: 14
            )

            HanokRoofSealOverlay(
                opacity: colorScheme == .dark ? 0.50 : 0.62,
                size: 54,
                topPadding: 16,
                trailingPadding: 18
            )
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }

    private var hanokGradientColors: [Color] {
        if isWeatherActive {
            if colorScheme == .dark {
                return [
                    atmosphere.waveColor(for: theme).opacity(DS.Opacity.strong),
                    theme.sandColor.opacity(DS.Opacity.light),
                    theme.hanokMistColor.opacity(DS.Opacity.medium),
                    .clear
                ]
            }
            return atmosphere.gradientColors(for: theme)
        }
        if colorScheme == .dark {
            return [
                theme.sandColor.opacity(DS.Opacity.light),
                theme.hanokMistColor.opacity(DS.Opacity.medium),
                theme.hanokMidColor.opacity(DS.Opacity.light),
                theme.hanokDeepColor.opacity(DS.Opacity.subtle),
                .clear
            ]
        }
        return [
            theme.sandColor.opacity(DS.Opacity.light),
            theme.hanokMistColor.opacity(DS.Opacity.medium),
            theme.hanokMidColor.opacity(DS.Opacity.medium),
            theme.hanokDeepColor.opacity(DS.Opacity.subtle),
            .clear
        ]
    }
}

// MARK: - Hanok Detail Background

/// Subtler 2-layer hanok eave for push-destination detail screens.
/// Positioned at the bottom of the screen.
struct HanokDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.25 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Far — distant rooftops
            HanokWaveOverlayView(
                color: theme.hanokMistColor,
                opacity: 0.09 * visibilityBoost,
                amplitude: 0.035,
                frequency: 1.2,
                verticalOffset: 0.42,
                bottomFade: 0.5,
                uplift: 0.18,
                driftDuration: 22,
                crestColor: theme.sandColor,
                crestOpacity: 0.12 * visibilityBoost,
                crestWidth: 0.9,
                breathIntensity: 0.04
            )
            .frame(height: 150)

            // Near — closer eave
            HanokWaveOverlayView(
                color: theme.hanokDeepColor,
                opacity: 0.45 * visibilityBoost,
                amplitude: 0.045,
                frequency: 1.8,
                verticalOffset: 0.58,
                bottomFade: 0.45,
                uplift: 0.22,
                tileRipple: 0.06,
                driftDuration: 18,
                showHanji: true,
                hanjiOpacity: colorScheme == .dark ? 0.010 : 0.022,
                crestColor: theme.sandColor,
                crestOpacity: 0.16 * visibilityBoost,
                crestWidth: 1.0,
                breathIntensity: 0.08
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    theme.sandColor.opacity(DS.Opacity.light),
                    (colorScheme == .dark ? theme.hanokMistColor : theme.hanokMidColor).opacity(DS.Opacity.light),
                    .clear
                ],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            HanokPavilionLandscapeOverlay(
                opacity: colorScheme == .dark ? 0.42 : 0.54,
                width: 146,
                topPadding: 28,
                leadingPadding: 14
            )

            HanokRoofSealOverlay(
                opacity: colorScheme == .dark ? 0.34 : 0.42,
                size: 44,
                topPadding: 14,
                trailingPadding: 16
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Hanok Sheet Background

/// Lightest single-layer hanok eave for sheet/modal presentations.
/// Minimal tile detail, positioned at the bottom.
struct HanokSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var visibilityBoost: Double {
        colorScheme == .dark ? 1.2 : 1.0
    }

    var body: some View {
        ZStack(alignment: .top) {
            HanokWaveOverlayView(
                color: theme.hanokMidColor,
                opacity: 0.09 * visibilityBoost,
                amplitude: 0.03,
                frequency: 0.7,
                verticalOffset: 0.40,
                bottomFade: 0.5,
                uplift: 0.15,
                driftDuration: 20,
                showHanji: true,
                hanjiOpacity: colorScheme == .dark ? 0.008 : 0.018,
                crestColor: theme.sandColor,
                crestOpacity: 0.12 * visibilityBoost,
                crestWidth: 1.0,
                breathIntensity: 0.04
            )
            .frame(height: 150)

            LinearGradient(
                colors: [
                    .clear,
                    theme.sandColor.opacity(DS.Opacity.subtle),
                    (colorScheme == .dark ? theme.hanokMistColor : theme.hanokMidColor).opacity(DS.Opacity.light)
                ],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )

            HanokPavilionLandscapeOverlay(
                opacity: colorScheme == .dark ? 0.24 : 0.34,
                width: 126,
                topPadding: 30,
                leadingPadding: 14
            )

            HanokRoofSealOverlay(
                opacity: colorScheme == .dark ? 0.26 : 0.34,
                size: 38,
                topPadding: 12,
                trailingPadding: 14
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("HanokTabWaveBackground") {
    HanokTabWaveBackground()
        .environment(\.appTheme, .hanok)
}

#Preview("Hanok Tab — All Presets") {
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
            HanokTabWaveBackground()
                .environment(\.wavePreset, preset)
                .environment(\.appTheme, .hanok)
                .overlay(alignment: .center) {
                    Text(name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .tabItem { Text(name) }
        }
    }
}

#Preview("Hanok Tab — Dark") {
    HanokTabWaveBackground()
        .environment(\.appTheme, .hanok)
        .preferredColorScheme(.dark)
}
