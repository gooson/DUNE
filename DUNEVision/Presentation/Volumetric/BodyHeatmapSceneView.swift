import RealityKit
import SwiftUI

struct BodyHeatmapSceneView: View {
    let muscleLoads: [SpatialTrainingSummary.MuscleLoad]
    let selectedMuscle: MuscleGroup?

    @State private var scene = MuscleMap3DScene()
    @State private var yaw: Float = MuscleMap3DState.defaultYaw
    @State private var pitch: Float = MuscleMap3DState.defaultPitch
    @State private var dragStartYaw: Float = MuscleMap3DState.defaultYaw
    @State private var dragStartPitch: Float = MuscleMap3DState.defaultPitch
    @State private var muscleLookup: [MuscleGroup: SpatialTrainingSummary.MuscleLoad] = [:]

    var body: some View {
        RealityView { content in
            if scene.anchor.parent == nil {
                content.add(scene.anchor)
            }
            await scene.prepareIfNeeded()
            applyShellMaterials()
            applyMuscleMaterials()
        } update: { _ in
            guard scene.isReady else { return }
            scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(rotationGesture)
        .task {
            muscleLookup = buildMuscleLookup()
        }
        .onChange(of: muscleLoads.count) { _, _ in
            muscleLookup = buildMuscleLookup()
            applyMuscleMaterials()
        }
        .onChange(of: selectedMuscle) { _, _ in
            applyMuscleMaterials()
        }
    }

    // MARK: - Visual Application

    private func applyShellMaterials() {
        // Volumetric context is always dark — hardcoded shell tint is intentional
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
    }

    private func applyMuscleMaterials() {
        guard scene.isReady else { return }

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
                repeating: isSelected ? MuscleMap3DState.selectedScale : 1.0
            )
            for model in scene.muscleModelEntities(for: muscle) {
                if var comp = model.model {
                    comp.materials = [material]
                    model.model = comp
                }
            }
        }
    }

    // MARK: - Helpers

    private func buildMuscleLookup() -> [MuscleGroup: SpatialTrainingSummary.MuscleLoad] {
        Dictionary(muscleLoads.map { ($0.muscle, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                yaw = dragStartYaw + Float(value.translation.width) * MuscleMap3DState.rotationSensitivity
                pitch = MuscleMap3DState.clampedPitch(
                    dragStartPitch + Float(value.translation.height) * MuscleMap3DState.pitchSensitivity
                )
            }
            .onEnded { _ in
                dragStartYaw = yaw
                dragStartPitch = pitch
            }
    }
}
