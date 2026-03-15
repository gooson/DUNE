import SwiftUI

/// Canvas overlay that renders joint angle arcs and values on the camera preview.
struct AngleOverlay: View {
    let angles: [RealtimeAngle]
    var isFrontCamera: Bool = false

    var body: some View {
        Canvas { context, size in
            for angle in angles {
                let screenPoint = visionToScreen(angle.displayPosition, size: size)
                drawAngleLabel(context: context, at: screenPoint, angle: angle)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Drawing

    private func drawAngleLabel(context: GraphicsContext, at point: CGPoint, angle: RealtimeAngle) {
        let color = statusColor(angle.status)
        let text = Text("\(Int(angle.degrees))°")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(color)

        // Background pill
        let bgRect = CGRect(
            x: point.x + 8,
            y: point.y - 10,
            width: 38,
            height: 20
        )
        context.fill(
            RoundedRectangle(cornerRadius: 4).path(in: bgRect),
            with: .color(.black.opacity(0.6))
        )

        // Text
        context.draw(
            context.resolve(text),
            at: CGPoint(x: bgRect.midX, y: bgRect.midY),
            anchor: .center
        )
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
