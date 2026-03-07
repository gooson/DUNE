import RealityKit
import SwiftUI

struct HeartRateOrbSceneView: View {
    let orb: SpatialTrainingSummary.HeartRateOrb

    @State private var yaw: Float = 0
    @State private var pitch: Float = 0
    @State private var dragStartYaw: Float = 0
    @State private var dragStartPitch: Float = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let pulse = pulseState(at: timeline.date)

            RealityView { content in
                let root = Entity()
                root.name = "orb-root"

                let orbEntity = ModelEntity(
                    mesh: .generateSphere(radius: 0.18),
                    materials: [SimpleMaterial(
                        color: VisionSpatialPalette.orbColor(heatLevel: orb.heatLevel),
                        roughness: 0.08,
                        isMetallic: false
                    )]
                )
                orbEntity.name = "orb-core"
                root.addChild(orbEntity)

                let haloEntity = ModelEntity(
                    mesh: .generateSphere(radius: 0.28),
                    materials: [SimpleMaterial(
                        color: VisionSpatialPalette.orbColor(heatLevel: orb.heatLevel, alpha: 0.16),
                        roughness: 0.02,
                        isMetallic: false
                    )]
                )
                haloEntity.name = "orb-halo"
                root.addChild(haloEntity)

                content.add(root)
            } update: { content in
                guard let root = content.entities.first(where: { $0.name == "orb-root" }) else { return }
                root.transform.rotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                    * simd_quatf(angle: pitch, axis: [1, 0, 0])
                root.position.y = pulse.floatY

                if let orbEntity = root.findEntity(named: "orb-core") as? ModelEntity {
                    orbEntity.scale = SIMD3<Float>(repeating: pulse.coreScale)
                }

                if let haloEntity = root.findEntity(named: "orb-halo") as? ModelEntity {
                    haloEntity.scale = SIMD3<Float>(repeating: pulse.haloScale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(rotationGesture)
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

    private func pulseState(at date: Date) -> PulseState {
        let bpm = Double(orb.displayBPM ?? 58)
        let radians = date.timeIntervalSinceReferenceDate * (bpm / 60.0) * (.pi * 2.0)
        let wave = (sin(radians) + 1) * 0.5
        let base = 0.84 + (orb.normalizedPulse * 0.18)
        let coreScale = Float(base + (wave * 0.18))
        let haloScale = Float(base + 0.52 + (wave * 0.12))
        let yOffset = Float((wave - 0.5) * 0.07)

        return PulseState(coreScale: coreScale, haloScale: haloScale, floatY: yOffset)
    }
}

private struct PulseState {
    let coreScale: Float
    let haloScale: Float
    let floatY: Float
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
