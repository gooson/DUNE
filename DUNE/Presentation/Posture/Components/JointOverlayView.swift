import SwiftUI

struct JointOverlayView: View {
    let jointPositions: [JointPosition3D]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / imageSize.width,
                geometry.size.height / imageSize.height
            )
            let offsetX = (geometry.size.width - imageSize.width * scale) / 2
            let offsetY = (geometry.size.height - imageSize.height * scale) / 2

            ZStack {
                // Connection lines
                connectionLines(scale: scale, offsetX: offsetX, offsetY: offsetY)

                // Joint dots
                ForEach(jointPositions) { joint in
                    if let point = projectToScreen(
                        joint: joint,
                        scale: scale,
                        offsetX: offsetX,
                        offsetY: offsetY
                    ) {
                        Circle()
                            .fill(jointColor(for: joint.name))
                            .frame(width: 10, height: 10)
                            .position(point)
                    }
                }
            }
        }
    }

    // MARK: - Projection

    private func projectToScreen(
        joint: JointPosition3D,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> CGPoint? {
        // Use 2D image coordinates from VNHumanBodyPose3DObservation.pointInImage
        guard let imageX = joint.imageX, let imageY = joint.imageY else {
            return nil
        }

        // Vision normalized coords: origin bottom-left, Y up → flip Y for UIKit
        return CGPoint(
            x: offsetX + imageX * imageSize.width * scale,
            y: offsetY + (1.0 - imageY) * imageSize.height * scale
        )
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

        return Path { path in
            for (from, to) in Self.connections {
                guard let fromJoint = jointMap[from],
                      let toJoint = jointMap[to],
                      let fromPoint = projectToScreen(
                          joint: fromJoint, scale: scale, offsetX: offsetX, offsetY: offsetY
                      ),
                      let toPoint = projectToScreen(
                          joint: toJoint, scale: scale, offsetX: offsetX, offsetY: offsetY
                      ) else { continue }

                path.move(to: fromPoint)
                path.addLine(to: toPoint)
            }
        }
        .stroke(.white.opacity(0.6), lineWidth: 2)
    }

    // MARK: - Colors

    private func jointColor(for name: String) -> Color {
        switch name {
        case "centerHead", "topHead":
            .cyan
        case "leftShoulder", "rightShoulder", "centerShoulder":
            .green
        case "spine", "root":
            .yellow
        case "leftHip", "rightHip":
            .orange
        case "leftKnee", "rightKnee", "leftAnkle", "rightAnkle":
            .mint
        default:
            .white
        }
    }
}
