import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

/// Uses a raster asset if available, otherwise falls back to procedural sigil.
///
/// Asset name: `ShanksPirateFlagMark`
struct ShanksPirateFlagMark: View {
    var body: some View {
        if let image = UIImage(named: "ShanksPirateFlagMark") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ShanksPirateFlagSigil()
                .fill(.white, style: FillStyle(eoFill: true))
        }
    }
}

struct ShanksFlagTextureView: View {
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

// MARK: - Shanks Tab Background

struct ShanksTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color
    @Environment(\.weatherAtmosphere) private var atmosphere

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    var body: some View {
        ShanksCinematicSceneBackground(
            style: .tab(for: preset),
            accentTint: isWeatherActive ? atmosphere.waveColor : color
        )
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }
}

// MARK: - Shanks Detail Background

struct ShanksDetailWaveBackground: View {
    @Environment(\.waveColor) private var color

    var body: some View {
        ShanksCinematicSceneBackground(
            style: .detail,
            accentTint: color
        )
    }
}

// MARK: - Shanks Sheet Background

struct ShanksSheetWaveBackground: View {
    var body: some View {
        ShanksCinematicSceneBackground(style: .sheet, accentTint: nil)
    }
}
