import RealityKit
import SwiftUI

struct BodyHeatmapSceneView: View {
    let muscleLoads: [SpatialTrainingSummary.MuscleLoad]
    let selectedMuscle: MuscleGroup?

    @State private var yaw: Float = 0.28
    @State private var pitch: Float = -0.16
    @State private var dragStartYaw: Float = 0.28
    @State private var dragStartPitch: Float = -0.16

    private var muscleLookup: [MuscleGroup: SpatialTrainingSummary.MuscleLoad] {
        Dictionary(muscleLoads.map { ($0.muscle, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = "body-heatmap-root"
            VisionBodyRig.install(into: root)
            content.add(root)
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "body-heatmap-root" }) else { return }
            VisionBodyRig.applyVisuals(
                root: root,
                muscleLoads: muscleLookup,
                selectedMuscle: selectedMuscle,
                yaw: yaw,
                pitch: pitch
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(rotationGesture)
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                yaw = dragStartYaw + Float(value.translation.width) * 0.008
                pitch = (dragStartPitch + Float(value.translation.height) * 0.004)
                    .clamped(to: -0.48...0.18)
            }
            .onEnded { _ in
                dragStartYaw = yaw
                dragStartPitch = pitch
            }
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
