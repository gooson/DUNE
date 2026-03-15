import SwiftUI

struct BodyGuideOverlay: View {
    let captureType: PostureCaptureType

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let height = geometry.size.height

            ZStack {
                // Semi-transparent background outside guide area
                Color.black.opacity(0.3)

                // Body silhouette guide
                bodyOutline(centerX: centerX, height: height)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(.white.opacity(0.6))

                // Foot position markers
                footMarkers(centerX: centerX, height: height)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Body Outline

    private func bodyOutline(centerX: CGFloat, height: CGFloat) -> Path {
        let bodyTop = height * 0.12
        let bodyBottom = height * 0.88
        let bodyHeight = bodyBottom - bodyTop

        switch captureType {
        case .front:
            return frontBodyPath(centerX: centerX, top: bodyTop, bodyHeight: bodyHeight)
        case .side:
            return sideBodyPath(centerX: centerX, top: bodyTop, bodyHeight: bodyHeight)
        }
    }

    private func frontBodyPath(centerX: CGFloat, top: CGFloat, bodyHeight: CGFloat) -> Path {
        let headRadius = bodyHeight * 0.06
        let shoulderWidth = bodyHeight * 0.18
        let hipWidth = bodyHeight * 0.14
        let footSpacing = bodyHeight * 0.08

        var path = Path()

        // Head circle
        let headCenter = CGPoint(x: centerX, y: top + headRadius)
        path.addEllipse(in: CGRect(
            x: headCenter.x - headRadius,
            y: headCenter.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))

        // Torso
        let neckY = top + headRadius * 2 + bodyHeight * 0.02
        let shoulderY = neckY + bodyHeight * 0.04
        let hipY = top + bodyHeight * 0.5

        path.move(to: CGPoint(x: centerX - shoulderWidth, y: shoulderY))
        path.addLine(to: CGPoint(x: centerX + shoulderWidth, y: shoulderY))
        path.addLine(to: CGPoint(x: centerX + hipWidth, y: hipY))
        path.addLine(to: CGPoint(x: centerX - hipWidth, y: hipY))
        path.closeSubpath()

        // Left leg
        let ankleY = top + bodyHeight
        path.move(to: CGPoint(x: centerX - hipWidth, y: hipY))
        path.addLine(to: CGPoint(x: centerX - footSpacing, y: ankleY))

        // Right leg
        path.move(to: CGPoint(x: centerX + hipWidth, y: hipY))
        path.addLine(to: CGPoint(x: centerX + footSpacing, y: ankleY))

        return path
    }

    private func sideBodyPath(centerX: CGFloat, top: CGFloat, bodyHeight: CGFloat) -> Path {
        let headRadius = bodyHeight * 0.06
        let bodyDepth = bodyHeight * 0.10

        var path = Path()

        // Head circle
        let headCenter = CGPoint(x: centerX, y: top + headRadius)
        path.addEllipse(in: CGRect(
            x: headCenter.x - headRadius,
            y: headCenter.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        ))

        // Torso (side profile — thinner)
        let neckY = top + headRadius * 2 + bodyHeight * 0.02
        let shoulderY = neckY + bodyHeight * 0.04
        let hipY = top + bodyHeight * 0.5
        let ankleY = top + bodyHeight

        path.move(to: CGPoint(x: centerX - bodyDepth, y: shoulderY))
        path.addLine(to: CGPoint(x: centerX + bodyDepth, y: shoulderY))
        path.addLine(to: CGPoint(x: centerX + bodyDepth * 0.5, y: hipY))
        path.addLine(to: CGPoint(x: centerX - bodyDepth * 0.5, y: hipY))
        path.closeSubpath()

        // Single leg line (side view)
        path.move(to: CGPoint(x: centerX, y: hipY))
        path.addLine(to: CGPoint(x: centerX, y: ankleY))

        return path
    }

    // MARK: - Foot Markers

    private func footMarkers(centerX: CGFloat, height: CGFloat) -> some View {
        let markerY = height * 0.90
        let spacing: CGFloat = captureType == .front ? height * 0.08 : 0

        return ZStack {
            if captureType == .front {
                // Two foot markers
                FootMarker()
                    .position(x: centerX - spacing, y: markerY)
                FootMarker()
                    .position(x: centerX + spacing, y: markerY)
            } else {
                // Single foot marker for side view
                FootMarker()
                    .position(x: centerX, y: markerY)
            }
        }
    }
}

// MARK: - Foot Marker

private struct FootMarker: View {
    var body: some View {
        Circle()
            .stroke(.white.opacity(0.5), lineWidth: 1.5)
            .frame(width: 24, height: 24)
            .overlay {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
    }
}
