import SwiftUI

/// Canvas overlay that renders joint angle arcs and values on the camera preview.
struct AngleOverlay: View {
    let angles: [RealtimeAngle]
    let keypoints: [(String, CGPoint)]
    var isFrontCamera: Bool = false

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear) { context, size in
            for angle in angles {
                guard let resolved = context.resolveSymbol(id: angle.id) else { continue }
                let position = keypointPosition(for: angle, size: size)
                // Draw background pill
                let bgRect = CGRect(
                    x: position.x + 8,
                    y: position.y - 10,
                    width: 38,
                    height: 20
                )
                context.fill(
                    RoundedRectangle(cornerRadius: 4).path(in: bgRect),
                    with: .color(.black.opacity(0.6))
                )
                context.draw(resolved, at: CGPoint(x: bgRect.midX, y: bgRect.midY), anchor: .center)
            }
        } symbols: {
            ForEach(angles) { angle in
                Text("\(Int(angle.degrees))°")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor(angle.status))
                    .tag(angle.id)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Position Lookup

    private func keypointPosition(for angle: RealtimeAngle, size: CGSize) -> CGPoint {
        let kpDict = Dictionary(keypoints, uniquingKeysWith: { _, last in last })
        if let point = kpDict[angle.jointName] {
            return visionToScreen(point, size: size)
        }
        // Fallback: center of screen
        return CGPoint(x: size.width / 2, y: size.height / 2)
    }

    // MARK: - Coordinate Conversion

    private func visionToScreen(_ point: CGPoint, size: CGSize) -> CGPoint {
        let x = isFrontCamera ? (1.0 - point.x) : point.x
        return CGPoint(
            x: x * size.width,
            y: (1.0 - point.y) * size.height
        )
    }

    // MARK: - Colors

    private func statusColor(_ status: PostureStatus) -> Color {
        switch status {
        case .normal: .green
        case .caution: .yellow
        case .warning: .red
        case .unmeasurable: .gray
        }
    }
}
