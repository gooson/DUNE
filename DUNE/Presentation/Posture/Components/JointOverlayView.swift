import SwiftUI

struct JointOverlayView: View {
    let jointPositions: [JointPosition3D]
    let imageSize: CGSize
    let metrics: [PostureMetricResult]
    let captureType: PostureCaptureType

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / imageSize.width,
                geometry.size.height / imageSize.height
            )
            let offsetX = (geometry.size.width - imageSize.width * scale) / 2
            let offsetY = (geometry.size.height - imageSize.height * scale) / 2

            ZStack {
                // Plumb line (ideal alignment reference)
                plumbLine(scale: scale, offsetX: offsetX, offsetY: offsetY)

                // Connection lines (color-coded by metric status)
                connectionLines(scale: scale, offsetX: offsetX, offsetY: offsetY)

                // Joint dots (color-coded by metric status)
                ForEach(jointPositions) { joint in
                    if let point = projectToScreen(
                        joint: joint,
                        scale: scale,
                        offsetX: offsetX,
                        offsetY: offsetY
                    ) {
                        Circle()
                            .fill(statusColor(for: joint.name))
                            .frame(width: 10, height: 10)
                            .position(point)
                    }
                }
            }
            .clipped()
        }
    }

    // MARK: - Projection

    private func projectToScreen(
        joint: JointPosition3D,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> CGPoint? {
        guard let imageX = joint.imageX, let imageY = joint.imageY else {
            return nil
        }

        // Vision normalized coords: origin bottom-left, Y up → flip Y for UIKit
        return CGPoint(
            x: offsetX + imageX * imageSize.width * scale,
            y: offsetY + (1.0 - imageY) * imageSize.height * scale
        )
    }

    // MARK: - Plumb Line

    private func plumbLine(
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        let jointMap = Dictionary(uniqueKeysWithValues: jointPositions.map { ($0.name, $0) })

        let anchorJoints: [(top: String, bottom: String)]
        switch captureType {
        case .front:
            anchorJoints = [("centerHead", "root")]
        case .side:
            anchorJoints = [("centerHead", "rightAnkle")]
        }

        return ZStack {
            ForEach(Array(anchorJoints.enumerated()), id: \.offset) { _, pair in
                if let topJoint = jointMap[pair.top],
                   let bottomJoint = jointMap[pair.bottom],
                   let topPoint = projectToScreen(
                       joint: topJoint, scale: scale, offsetX: offsetX, offsetY: offsetY
                   ),
                   let bottomPoint = projectToScreen(
                       joint: bottomJoint, scale: scale, offsetX: offsetX, offsetY: offsetY
                   ) {
                    // Ideal vertical line (plumb line) — from top anchor X, full height
                    Path { path in
                        path.move(to: CGPoint(x: topPoint.x, y: topPoint.y))
                        path.addLine(to: CGPoint(x: topPoint.x, y: bottomPoint.y))
                    }
                    .stroke(
                        .cyan.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )

                    // Actual alignment line — connecting actual joint positions
                    Path { path in
                        path.move(to: topPoint)
                        path.addLine(to: bottomPoint)
                    }
                    .stroke(.white.opacity(0.8), lineWidth: 1.5)
                }
            }
        }
    }

    // MARK: - Connections

    private static let connections: [(String, String)] = [
        ("topHead", "centerHead"),
        ("centerHead", "centerShoulder"),
        ("centerShoulder", "leftShoulder"),
        ("centerShoulder", "rightShoulder"),
        ("leftShoulder", "leftElbow"),
        ("leftElbow", "leftWrist"),
        ("rightShoulder", "rightElbow"),
        ("rightElbow", "rightWrist"),
        ("centerShoulder", "spine"),
        ("spine", "root"),
        ("root", "leftHip"),
        ("root", "rightHip"),
        ("leftHip", "leftKnee"),
        ("leftKnee", "leftAnkle"),
        ("rightHip", "rightKnee"),
        ("rightKnee", "rightAnkle"),
    ]

    private func connectionLines(
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        let jointMap = Dictionary(uniqueKeysWithValues: jointPositions.map { ($0.name, $0) })

        return ForEach(Array(Self.connections.enumerated()), id: \.offset) { _, connection in
            if let fromJoint = jointMap[connection.0],
               let toJoint = jointMap[connection.1],
               let fromPoint = projectToScreen(
                   joint: fromJoint, scale: scale, offsetX: offsetX, offsetY: offsetY
               ),
               let toPoint = projectToScreen(
                   joint: toJoint, scale: scale, offsetX: offsetX, offsetY: offsetY
               ) {
                Path { path in
                    path.move(to: fromPoint)
                    path.addLine(to: toPoint)
                }
                .stroke(
                    segmentColor(from: connection.0, to: connection.1),
                    lineWidth: 2
                )
            }
        }
    }

    // MARK: - Status-Based Colors

    /// Builds a lookup from joint name to worst PostureStatus affecting that joint.
    private var jointStatusMap: [String: PostureStatus] {
        let measurable = metrics.filter { $0.status != .unmeasurable }
        var map: [String: PostureStatus] = [:]
        for metric in measurable {
            for jointName in metric.type.affectedJointNames {
                if let existing = map[jointName] {
                    if metric.status > existing {
                        map[jointName] = metric.status
                    }
                } else {
                    map[jointName] = metric.status
                }
            }
        }
        return map
    }

    private func statusColor(for jointName: String) -> Color {
        guard let status = jointStatusMap[jointName] else {
            return .white.opacity(0.8)
        }
        return status.color
    }

    private func segmentColor(from: String, to: String) -> Color {
        let fromStatus = jointStatusMap[from]
        let toStatus = jointStatusMap[to]

        // Use the worse status of the two endpoints
        let status: PostureStatus?
        switch (fromStatus, toStatus) {
        case let (.some(a), .some(b)):
            status = max(a, b)
        case let (.some(a), .none):
            status = a
        case let (.none, .some(b)):
            status = b
        case (.none, .none):
            status = nil
        }

        guard let status else {
            return .white.opacity(0.6)
        }
        return status.color.opacity(0.8)
    }
}
