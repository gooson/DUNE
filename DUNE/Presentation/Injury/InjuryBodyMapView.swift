import SwiftUI

/// Body map overlay showing injury locations.
/// Joint injuries use bullseye ring markers; muscle injuries highlight the muscle region.
struct InjuryBodyMapView: View {
    let injuries: [InjuryRecord]
    let showingFront: Bool

    @Environment(\.colorScheme) private var colorScheme

    /// Joint positions on the body map (normalized 0...1 within 724x1448 viewBox).
    private static let jointPositions: [BodyPart: JointPosition] = [
        .neck:      JointPosition(front: CGPoint(x: 362, y: 250), back: CGPoint(x: 362, y: 250)),
        .shoulder:  JointPosition(front: CGPoint(x: 230, y: 320), back: CGPoint(x: 230, y: 320), isBilateral: true, rightFront: CGPoint(x: 494, y: 320), rightBack: CGPoint(x: 494, y: 320)),
        .elbow:     JointPosition(front: CGPoint(x: 185, y: 490), back: CGPoint(x: 185, y: 490), isBilateral: true, rightFront: CGPoint(x: 539, y: 490), rightBack: CGPoint(x: 539, y: 490)),
        .wrist:     JointPosition(front: CGPoint(x: 150, y: 640), back: CGPoint(x: 150, y: 640), isBilateral: true, rightFront: CGPoint(x: 574, y: 640), rightBack: CGPoint(x: 574, y: 640)),
        .lowerBack: JointPosition(front: nil, back: CGPoint(x: 362, y: 610)),
        .hip:       JointPosition(front: CGPoint(x: 290, y: 700), back: CGPoint(x: 290, y: 700), isBilateral: true, rightFront: CGPoint(x: 434, y: 700), rightBack: CGPoint(x: 434, y: 700)),
        .knee:      JointPosition(front: CGPoint(x: 300, y: 930), back: CGPoint(x: 300, y: 930), isBilateral: true, rightFront: CGPoint(x: 424, y: 930), rightBack: CGPoint(x: 424, y: 930)),
        .ankle:     JointPosition(front: CGPoint(x: 305, y: 1180), back: CGPoint(x: 305, y: 1180), isBilateral: true, rightFront: CGPoint(x: 419, y: 1180), rightBack: CGPoint(x: 419, y: 1180)),
    ]

    /// SVG viewBox size for coordinate normalization.
    private static let viewBoxSize = MuscleMapData.svgFrontViewBox

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Muscle region highlights for non-joint injuries
                ForEach(muscleInjuries) { injury in
                    muscleOverlay(for: injury, width: width, height: height)
                }

                // Joint markers
                ForEach(jointInjuries) { injury in
                    jointMarkers(for: injury, width: width, height: height)
                }
            }
            .frame(width: width, height: height)
        }
    }

    // MARK: - Filtered Injuries

    private var jointInjuries: [InjuryRecord] {
        injuries.filter(\.bodyPart.isJoint)
    }

    private var muscleInjuries: [InjuryRecord] {
        injuries.filter { !$0.bodyPart.isJoint }
    }

    // MARK: - Joint Markers

    @ViewBuilder
    private func jointMarkers(for injury: InjuryRecord, width: CGFloat, height: CGFloat) -> some View {
        if let positions = Self.jointPositions[injury.bodyPart] {
            let markerSize: CGFloat = 20

            if positions.isBilateral {
                let side = injury.bodySide ?? .both

                if side == .left || side == .both {
                    if let pos = showingFront ? positions.front : positions.back {
                        JointMarkerView(severity: injury.severity, isActive: injury.isActive)
                            .frame(width: markerSize, height: markerSize)
                            .position(
                                x: pos.x / Self.viewBoxSize.width * width,
                                y: pos.y / Self.viewBoxSize.height * height
                            )
                    }
                }

                if side == .right || side == .both {
                    if let pos = showingFront ? positions.rightFront : positions.rightBack {
                        JointMarkerView(severity: injury.severity, isActive: injury.isActive)
                            .frame(width: markerSize, height: markerSize)
                            .position(
                                x: pos.x / Self.viewBoxSize.width * width,
                                y: pos.y / Self.viewBoxSize.height * height
                            )
                    }
                }
            } else {
                // Non-bilateral (neck, lower back)
                if let pos = jointPosition(for: injury.bodyPart, positions: positions) {
                    JointMarkerView(severity: injury.severity, isActive: injury.isActive)
                        .frame(width: markerSize, height: markerSize)
                        .position(
                            x: pos.x / Self.viewBoxSize.width * width,
                            y: pos.y / Self.viewBoxSize.height * height
                        )
                }
            }
        }
    }

    private func jointPosition(for bodyPart: BodyPart, positions: JointPosition) -> CGPoint? {
        if bodyPart == .lowerBack {
            return showingFront ? nil : positions.back
        } else {
            return showingFront ? positions.front : positions.back
        }
    }

    // MARK: - Muscle Overlay

    @ViewBuilder
    private func muscleOverlay(for injury: InjuryRecord, width: CGFloat, height: CGFloat) -> some View {
        let muscles = injury.bodyPart.affectedMuscleGroups
        let parts = showingFront ? MuscleMapData.svgFrontParts : MuscleMapData.svgBackParts
        let matchingParts = parts.filter { muscles.contains($0.muscle) }

        ForEach(matchingParts) { part in
            part.shape
                .fill(injury.severity.color.opacity(injury.isActive ? 0.35 : 0.15))
                .overlay {
                    part.shape
                        .stroke(injury.severity.color.opacity(injury.isActive ? 0.6 : 0.3), lineWidth: 1)
                }
                .frame(width: width, height: height)
        }
    }
}

// MARK: - Joint Position Data

private struct JointPosition {
    let front: CGPoint?
    let back: CGPoint?
    let isBilateral: Bool
    let rightFront: CGPoint?
    let rightBack: CGPoint?

    init(
        front: CGPoint? = nil,
        back: CGPoint? = nil,
        isBilateral: Bool = false,
        rightFront: CGPoint? = nil,
        rightBack: CGPoint? = nil
    ) {
        self.front = front
        self.back = back
        self.isBilateral = isBilateral
        self.rightFront = rightFront
        self.rightBack = rightBack
    }
}
