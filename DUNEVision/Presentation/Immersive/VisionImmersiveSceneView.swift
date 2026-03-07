import RealityKit
import SwiftUI
import UIKit

struct VisionImmersiveSceneView: View {
    let summary: ImmersiveRecoverySummary
    let mode: VisionImmersiveMode
    let breathPhase: Double
    let journeyProgress: Double

    @State private var scene = VisionImmersiveScene()

    var body: some View {
        RealityView { content in
            if scene.root.parent == nil {
                content.add(scene.root)
            }
            scene.installIfNeeded()
            scene.update(
                summary: summary,
                mode: mode,
                breathPhase: breathPhase,
                journeyProgress: journeyProgress
            )
        } update: { _ in
            scene.update(
                summary: summary,
                mode: mode,
                breathPhase: breathPhase,
                journeyProgress: journeyProgress
            )
        }
    }
}

@MainActor
final class VisionImmersiveScene {
    let root = Entity()

    private let ambientRoot = Entity()
    private let recoveryRoot = Entity()
    private let sleepRoot = Entity()

    private let ambientOrbs: [ModelEntity]
    private let recoveryCore: ModelEntity
    private let recoveryHaloA: ModelEntity
    private let recoveryHaloB: ModelEntity
    private var sleepColumns: [ModelEntity] = []

    private var isInstalled = false

    init() {
        ambientOrbs = (0..<12).map { index in
            let entity = ModelEntity(
                mesh: .generateSphere(radius: 0.11),
                materials: [SimpleMaterial(color: .white.withAlphaComponent(0.28), isMetallic: false)]
            )
            entity.name = "ambient-\(index)"
            return entity
        }

        recoveryCore = ModelEntity(
            mesh: .generateSphere(radius: 0.24),
            materials: [SimpleMaterial(color: .white.withAlphaComponent(0.42), roughness: 0.16, isMetallic: false)]
        )
        recoveryCore.name = "recovery-core"

        recoveryHaloA = ModelEntity(
            mesh: .generateSphere(radius: 0.38),
            materials: [SimpleMaterial(color: .white.withAlphaComponent(0.16), roughness: 0.08, isMetallic: false)]
        )
        recoveryHaloA.name = "recovery-halo-a"

        recoveryHaloB = ModelEntity(
            mesh: .generateSphere(radius: 0.54),
            materials: [SimpleMaterial(color: .white.withAlphaComponent(0.10), roughness: 0.08, isMetallic: false)]
        )
        recoveryHaloB.name = "recovery-halo-b"

    }

    func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true

        root.position = [0, 1.25, -2.15]

        ambientRoot.name = "ambient-root"
        recoveryRoot.name = "recovery-root"
        sleepRoot.name = "sleep-root"

        for orb in ambientOrbs {
            ambientRoot.addChild(orb)
        }

        recoveryRoot.addChild(recoveryHaloB)
        recoveryRoot.addChild(recoveryHaloA)
        recoveryRoot.addChild(recoveryCore)

        root.addChild(ambientRoot)
        root.addChild(recoveryRoot)
        root.addChild(sleepRoot)
    }

    func update(
        summary: ImmersiveRecoverySummary,
        mode: VisionImmersiveMode,
        breathPhase: Double,
        journeyProgress: Double
    ) {
        updateAmbientOrbs(
            atmosphere: summary.atmosphere,
            mode: mode,
            breathPhase: breathPhase,
            journeyProgress: journeyProgress
        )
        updateRecoveryScene(
            session: summary.recoverySession,
            mode: mode,
            breathPhase: breathPhase
        )
        updateSleepScene(
            journey: summary.sleepJourney,
            mode: mode,
            journeyProgress: journeyProgress
        )
    }

    private func updateAmbientOrbs(
        atmosphere: ImmersiveRecoverySummary.Atmosphere,
        mode: VisionImmersiveMode,
        breathPhase: Double,
        journeyProgress: Double
    ) {
        let baseColor = VisionImmersivePalette.atmosphereColor(for: atmosphere.preset)

        for (index, orb) in ambientOrbs.enumerated() {
            let fraction = Double(index) / Double(max(ambientOrbs.count - 1, 1))
            let angle = (fraction * .pi * 2.0) + (journeyProgress * 0.4)
            let radius: Float = mode == .recovery ? 2.5 : 3.1
            let verticalDrift = Float(sin((journeyProgress * 6.0) + fraction * 5.0) * 0.16)
            orb.position = [
                cos(Float(angle)) * radius,
                Float(-0.2 + (fraction * 1.2)) + verticalDrift,
                sin(Float(angle)) * radius
            ]

            let scaleBase: Float
            switch mode {
            case .atmosphere:
                scaleBase = 1.0
            case .recovery:
                scaleBase = 0.76 + Float(breathPhase * 0.32)
            case .sleepJourney:
                scaleBase = 0.86
            }
            orb.scale = SIMD3<Float>(repeating: scaleBase)

            let alpha = mode == .sleepJourney ? 0.14 : 0.22
            applyMaterial(
                to: orb,
                color: baseColor.withAlphaComponent(alpha),
                roughness: 0.14
            )
        }
    }

    private func updateRecoveryScene(
        session: ImmersiveRecoverySummary.RecoverySession,
        mode: VisionImmersiveMode,
        breathPhase: Double
    ) {
        let isVisible = mode == .recovery || mode == .atmosphere
        recoveryRoot.isEnabled = isVisible

        guard isVisible else { return }

        let highlightColor = VisionImmersivePalette.recoveryColor(for: session.recommendation)
        let coreScale = 0.85 + Float(breathPhase * 0.38)
        let haloAScale = 0.86 + Float((1.0 - breathPhase) * 0.42)
        let haloBScale = 0.82 + Float(breathPhase * 0.24)

        recoveryRoot.position = [0, mode == .recovery ? 0.08 : 0.16, 0]

        recoveryCore.scale = SIMD3<Float>(repeating: coreScale)
        recoveryHaloA.scale = SIMD3<Float>(repeating: haloAScale)
        recoveryHaloB.scale = SIMD3<Float>(repeating: haloBScale)

        applyMaterial(
            to: recoveryCore,
            color: highlightColor.withAlphaComponent(mode == .recovery ? 0.72 : 0.36),
            roughness: 0.08
        )
        applyMaterial(
            to: recoveryHaloA,
            color: highlightColor.withAlphaComponent(mode == .recovery ? 0.18 : 0.08),
            roughness: 0.04
        )
        applyMaterial(
            to: recoveryHaloB,
            color: highlightColor.withAlphaComponent(mode == .recovery ? 0.10 : 0.05),
            roughness: 0.04
        )
    }

    private func updateSleepScene(
        journey: ImmersiveRecoverySummary.SleepJourney,
        mode: VisionImmersiveMode,
        journeyProgress: Double
    ) {
        ensureSleepColumns(count: journey.segments.count)
        sleepRoot.isEnabled = mode == .sleepJourney && journey.hasData
        guard sleepRoot.isEnabled else {
            for column in sleepColumns {
                column.isEnabled = false
            }
            return
        }

        let maxMinutes = max(journey.segments.map(\.durationMinutes).max() ?? 1, 1)
        let offset = Float(journey.segments.count - 1) * 0.22

        for (index, column) in sleepColumns.enumerated() {
            guard index < journey.segments.count else {
                column.isEnabled = false
                continue
            }

            column.isEnabled = true
            let segment = journey.segments[index]
            let normalizedHeight = Float(segment.durationMinutes / maxMinutes)
            let height = max(0.18, normalizedHeight * 0.92)
            let width = max(0.16, Float((segment.endProgress - segment.startProgress) * 2.0))
            let isActive = journeyProgress >= segment.startProgress && journeyProgress <= segment.endProgress

            column.position = [
                (Float(index) * 0.44) - offset,
                -0.35 + (height / 2.0),
                0
            ]
            column.scale = [width, height, 0.12]

            let color = VisionImmersivePalette.sleepColor(
                for: segment.stage,
                active: isActive
            )
            applyMaterial(
                to: column,
                color: color.withAlphaComponent(isActive ? 0.9 : 0.5),
                roughness: isActive ? 0.08 : 0.16
            )
        }
    }

    private func ensureSleepColumns(count: Int) {
        guard sleepColumns.count != count else { return }

        if sleepColumns.count < count {
            let missingCount = count - sleepColumns.count
            let startIndex = sleepColumns.count
            let newColumns = (0..<missingCount).map { offset in
                makeSleepColumn(index: startIndex + offset)
            }
            for column in newColumns {
                sleepRoot.addChild(column)
            }
            sleepColumns.append(contentsOf: newColumns)
            return
        }

        let removedColumns = sleepColumns[count...]
        for column in removedColumns {
            column.removeFromParent()
        }
        sleepColumns.removeSubrange(count...)
    }

    private func makeSleepColumn(index: Int) -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generateBox(size: [0.18, 0.24, 0.08]),
            materials: [SimpleMaterial(color: .white.withAlphaComponent(0.22), roughness: 0.22, isMetallic: false)]
        )
        entity.name = "sleep-\(index)"
        return entity
    }

    private func applyMaterial(
        to entity: ModelEntity,
        color: UIColor,
        roughness: Float
    ) {
        if var model = entity.model {
            model.materials = [
                SimpleMaterial(
                    color: color,
                    roughness: .float(roughness),
                    isMetallic: false
                )
            ]
            entity.model = model
        }
    }
}

private enum VisionImmersivePalette {
    static func atmosphereColor(for preset: ConditionAtmospherePreset) -> UIColor {
        switch preset {
        case .sunrise:
            UIColor(red: 0.95, green: 0.72, blue: 0.34, alpha: 1)
        case .clouded:
            UIColor(red: 0.60, green: 0.78, blue: 0.88, alpha: 1)
        case .mist:
            UIColor(red: 0.50, green: 0.70, blue: 0.76, alpha: 1)
        case .storm:
            UIColor(red: 0.24, green: 0.36, blue: 0.52, alpha: 1)
        }
    }

    static func recoveryColor(for recommendation: RecoveryRecommendation) -> UIColor {
        switch recommendation {
        case .sustain:
            UIColor(red: 0.34, green: 0.80, blue: 0.70, alpha: 1)
        case .rebalance:
            UIColor(red: 0.48, green: 0.70, blue: 0.92, alpha: 1)
        case .restore:
            UIColor(red: 0.92, green: 0.62, blue: 0.34, alpha: 1)
        }
    }

    static func sleepColor(
        for stage: SleepStage.Stage,
        active: Bool
    ) -> UIColor {
        let base: UIColor
        switch stage {
        case .awake:
            base = UIColor(red: 0.93, green: 0.76, blue: 0.34, alpha: 1)
        case .core:
            base = UIColor(red: 0.36, green: 0.72, blue: 0.92, alpha: 1)
        case .deep:
            base = UIColor(red: 0.24, green: 0.46, blue: 0.86, alpha: 1)
        case .rem:
            base = UIColor(red: 0.92, green: 0.48, blue: 0.62, alpha: 1)
        case .unspecified:
            base = UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
        }

        guard active else { return base }
        return base.blended(with: .white, ratio: 0.18)
    }
}
