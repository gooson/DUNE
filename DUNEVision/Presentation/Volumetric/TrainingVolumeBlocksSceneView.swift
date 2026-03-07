import RealityKit
import SwiftUI

struct TrainingVolumeBlocksSceneView: View {
    let muscles: [SpatialTrainingSummary.MuscleLoad]
    let selectedMuscle: MuscleGroup?

    @State private var yaw: Float = 0.28
    @State private var pitch: Float = -0.16
    @State private var dragStartYaw: Float = 0.28
    @State private var dragStartPitch: Float = -0.16

    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = "blocks-root"
            installBase(into: root)
            installBlocks(into: root)
            content.add(root)
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "blocks-root" }) else { return }
            root.transform.rotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                * simd_quatf(angle: pitch, axis: [1, 0, 0])

            for (index, muscleLoad) in muscles.enumerated() {
                let name = "block.\(muscleLoad.muscle.rawValue)"
                guard let block = root.findEntity(named: name) as? ModelEntity else { continue }

                let blockHeight = height(for: muscleLoad)
                let isSelected = selectedMuscle == muscleLoad.muscle
                block.scale = SIMD3<Float>(
                    x: isSelected ? 1.08 : 1.0,
                    y: blockHeight,
                    z: isSelected ? 1.08 : 1.0
                )
                block.position = blockPosition(for: index, heightScale: blockHeight)

                if var model = block.model {
                    model.materials = [SimpleMaterial(
                        color: VisionSpatialPalette.blockColor(for: muscleLoad.muscle, selected: isSelected),
                        roughness: 0.22,
                        isMetallic: false
                    )]
                    block.model = model
                }
            }
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

    private func installBase(into root: Entity) {
        let base = ModelEntity(
            mesh: .generateBox(size: [1.28, 0.04, 0.48]),
            materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.08), roughness: 0.6, isMetallic: false)]
        )
        base.name = "base"
        base.position = [0, -0.30, -0.96]
        root.addChild(base)
    }

    private func installBlocks(into root: Entity) {
        for (index, muscleLoad) in muscles.enumerated() {
            let block = ModelEntity(
                mesh: .generateBox(size: [0.12, 0.20, 0.12]),
                materials: [SimpleMaterial(color: VisionSpatialPalette.blockColor(for: muscleLoad.muscle, selected: false), roughness: 0.22, isMetallic: false)]
            )
            block.name = "block.\(muscleLoad.muscle.rawValue)"
            let blockHeight = height(for: muscleLoad)
            block.scale = SIMD3<Float>(x: 1, y: blockHeight, z: 1)
            block.position = blockPosition(for: index, heightScale: blockHeight)
            root.addChild(block)
        }
    }

    private func blockPosition(for index: Int, heightScale: Float) -> SIMD3<Float> {
        let x = -0.50 + (Float(index) * 0.20)
        let baseHeight: Float = 0.20
        return SIMD3<Float>(x, -0.30 + ((baseHeight * heightScale) / 2), -0.96)
    }

    private func height(for muscleLoad: SpatialTrainingSummary.MuscleLoad) -> Float {
        let normalized = max(0.35, min(Float(muscleLoad.weeklyLoadUnits) / 8.0, 2.4))
        return normalized
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
