import RealityKit
import SwiftUI

struct BodyHeatmapSceneView: View {
    let muscleLoads: [SpatialTrainingSummary.MuscleLoad]
    let selectedMuscle: MuscleGroup?

    @State private var scene = MuscleMap3DScene()
    @State private var yaw: Float = 0.28
    @State private var pitch: Float = -0.16
    @State private var dragStartYaw: Float = 0.28
    @State private var dragStartPitch: Float = -0.16

    private var muscleLookup: [MuscleGroup: SpatialTrainingSummary.MuscleLoad] {
        Dictionary(muscleLoads.map { ($0.muscle, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    var body: some View {
        RealityView { content in
            content.add(scene.anchor)
            await scene.prepareIfNeeded()
        } update: { _ in
            guard scene.isReady else { return }
            applyHeatmapVisuals()
            scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(rotationGesture)
    }

    private func applyHeatmapVisuals() {
        for model in scene.shellModelEntities {
            if var comp = model.model {
                comp.materials = [SimpleMaterial(
                    color: UIColor.white.withAlphaComponent(0.07),
                    roughness: 0.42,
                    isMetallic: false
                )]
                model.model = comp
            }
        }

        for muscle in MuscleGroup.allCases {
            let state = muscleLookup[muscle]
            let isSelected = muscle == selectedMuscle
            let color = VisionSpatialPalette.fatigueColor(
                normalizedFatigue: state?.normalizedFatigue ?? 0,
                isSelected: isSelected
            )
            let material = SimpleMaterial(
                color: color,
                roughness: isSelected ? 0.16 : 0.34,
                isMetallic: false
            )

            scene.muscleEntity(for: muscle)?.scale = SIMD3<Float>(
                repeating: isSelected ? 1.08 : 1.0
            )
            for model in scene.muscleModelEntities(for: muscle) {
                if var comp = model.model {
                    comp.materials = [material]
                    model.model = comp
                }
            }
        }
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
