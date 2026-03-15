import SwiftUI

/// Zone-based posture guide overlay with real-time skeleton rendering.
struct BodyGuideOverlay: View {
    let captureType: PostureCaptureType
    let guidanceState: GuidanceState
    let skeletonKeypoints: [(String, CGPoint)]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Zone border (green when body detected, white otherwise)
                zoneGuide(size: geometry.size)

                // Real-time skeleton overlay
                if !skeletonKeypoints.isEmpty {
                    skeletonOverlay(size: geometry.size)
                }

                // Foot markers
                footMarkers(size: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Zone Guide

    private func zoneGuide(size: CGSize) -> some View {
        let inset: CGFloat = 40
        let topPadding = size.height * 0.08
        let bottomPadding = size.height * 0.06
        let rect = CGRect(
            x: inset,
            y: topPadding,
            width: size.width - inset * 2,
            height: size.height - topPadding - bottomPadding
        )

        let borderColor: Color = guidanceState.isFullBodyVisible
            ? (guidanceState.distanceStatus == .optimal ? .green : .yellow)
            : .white.opacity(0.5)

        return RoundedRectangle(cornerRadius: 20)
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [12, 6]))
            .foregroundStyle(borderColor)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .animation(.easeInOut(duration: 0.3), value: guidanceState.isFullBodyVisible)
            .animation(.easeInOut(duration: 0.3), value: guidanceState.distanceStatus)
    }

    // MARK: - Skeleton Overlay

    private func skeletonOverlay(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let kpMap = Dictionary(
                skeletonKeypoints.map { ($0.0, $0.1) },
                uniquingKeysWith: { _, last in last }
            )

            // Draw connections
            let connections: [(String, String)] = [
                ("leftShoulder", "rightShoulder"),
                ("leftShoulder", "leftElbow"), ("leftElbow", "leftWrist"),
                ("rightShoulder", "rightElbow"), ("rightElbow", "rightWrist"),
                ("leftShoulder", "leftHip"), ("rightShoulder", "rightHip"),
                ("leftHip", "rightHip"),
                ("leftHip", "leftKnee"), ("leftKnee", "leftAnkle"),
                ("rightHip", "rightKnee"), ("rightKnee", "rightAnkle"),
            ]

            let lineColor = guidanceState.isReady
                ? Color.green.opacity(0.7)
                : Color.white.opacity(0.5)

            for (from, to) in connections {
                guard let p1 = kpMap[from], let p2 = kpMap[to] else { continue }
                let start = visionToScreen(p1, size: canvasSize)
                let end = visionToScreen(p2, size: canvasSize)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(lineColor), lineWidth: 2)
            }

            // Draw joint dots
            let dotColor = guidanceState.isReady
                ? Color.green
                : Color.cyan.opacity(0.8)

            for (_, point) in skeletonKeypoints {
                let screenPoint = visionToScreen(point, size: canvasSize)
                let dotRect = CGRect(
                    x: screenPoint.x - 4,
                    y: screenPoint.y - 4,
                    width: 8,
                    height: 8
                )
                context.fill(Circle().path(in: dotRect), with: .color(dotColor))
            }
        }
    }

    /// Convert Vision normalized coordinates (origin bottom-left) to screen coordinates (origin top-left).
    private func visionToScreen(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: (1.0 - point.y) * size.height
        )
    }

    // MARK: - Foot Markers

    private func footMarkers(size: CGSize) -> some View {
        let markerY = size.height * 0.90
        let centerX = size.width / 2
        let spacing = size.height * 0.06

        return ZStack {
            if captureType == .front {
                FootPositionMarker()
                    .position(x: centerX - spacing, y: markerY)
                FootPositionMarker()
                    .position(x: centerX + spacing, y: markerY)
            } else {
                FootPositionMarker()
                    .position(x: centerX, y: markerY)
            }
        }
        .opacity(guidanceState.isFullBodyVisible ? 0.3 : 0.6)
    }
}

// MARK: - Foot Position Marker

private struct FootPositionMarker: View {
    var body: some View {
        Image(systemName: "shoe.fill")
            .font(.system(size: 18))
            .foregroundStyle(.white.opacity(0.5))
    }
}
