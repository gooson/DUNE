import RealityKit
import SwiftUI
import UIKit

enum VisionSpatialSceneKind: String, CaseIterable, Identifiable {
    case heartRateOrb
    case trainingBlocks
    case bodyHeatmap

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .heartRateOrb:
            "Heart Orb"
        case .trainingBlocks:
            "Load Blocks"
        case .bodyHeatmap:
            "Body Heatmap"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .heartRateOrb:
            "Pulsing sphere driven by your latest heart rate."
        case .trainingBlocks:
            "HealthKit-derived muscle workload as stacked blocks."
        case .bodyHeatmap:
            "Procedural body rig colored by recent fatigue."
        }
    }
}

extension MuscleGroup {
    var spatialDisplayName: String {
        switch self {
        case .chest: String(localized: "Chest")
        case .back: String(localized: "Back")
        case .shoulders: String(localized: "Shoulders")
        case .biceps: String(localized: "Biceps")
        case .triceps: String(localized: "Triceps")
        case .quadriceps: String(localized: "Quads")
        case .hamstrings: String(localized: "Hamstrings")
        case .glutes: String(localized: "Glutes")
        case .calves: String(localized: "Calves")
        case .core: String(localized: "Core")
        case .forearms: String(localized: "Forearms")
        case .traps: String(localized: "Traps")
        case .lats: String(localized: "Lats")
        }
    }

    var spatialIconName: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back, .lats: "dumbbell.fill"
        case .shoulders, .traps: "figure.arms.open"
        case .biceps, .triceps, .forearms: "dumbbell.fill"
        case .quadriceps, .hamstrings, .glutes, .calves: "figure.walk"
        case .core: "figure.core.training"
        }
    }
}

extension SpatialTrainingSummary.MuscleLoad {
    var recoveryLabel: String {
        guard hasRecentLoad else { return String(localized: "No recent load") }
        let percent = Int((recoveryPercent * 100).rounded())
        return String(localized: "\(percent.formatted())% recovered")
    }

    var loadLabel: String {
        String(localized: "\(weeklyLoadUnits.formatted()) u")
    }

    var fatigueLabel: String {
        switch fatigueLevel {
        case .noData: String(localized: "No Data")
        case .fullyRecovered: String(localized: "Recovered")
        case .wellRested: String(localized: "Well Rested")
        case .lightFatigue: String(localized: "Light Fatigue")
        case .mildFatigue: String(localized: "Mild Fatigue")
        case .moderateFatigue: String(localized: "Moderate Fatigue")
        case .notableFatigue: String(localized: "Notable Fatigue")
        case .highFatigue: String(localized: "High Fatigue")
        case .veryHighFatigue: String(localized: "Very High Fatigue")
        case .extremeFatigue: String(localized: "Extreme Fatigue")
        case .overtrained: String(localized: "Overtrained")
        }
    }
}

enum VisionSpatialPalette {
    static func orbColor(heatLevel: Double, alpha: CGFloat = 1.0) -> UIColor {
        let level = heatLevel.clamped(to: 0...1)
        return UIColor(
            hue: 0.62 - (0.56 * level),
            saturation: 0.48 + (0.32 * level),
            brightness: 0.92,
            alpha: alpha
        )
    }

    static func muscleColor(for muscle: MuscleGroup, alpha: CGFloat = 1.0) -> UIColor {
        let hue: CGFloat
        switch muscle {
        case .chest: hue = 0.02
        case .back: hue = 0.58
        case .shoulders: hue = 0.11
        case .biceps: hue = 0.08
        case .triceps: hue = 0.14
        case .quadriceps: hue = 0.30
        case .hamstrings: hue = 0.35
        case .glutes: hue = 0.42
        case .calves: hue = 0.50
        case .core: hue = 0.18
        case .forearms: hue = 0.66
        case .traps: hue = 0.74
        case .lats: hue = 0.82
        }

        return UIColor(hue: hue, saturation: 0.56, brightness: 0.94, alpha: alpha)
    }

    static func fatigueColor(
        normalizedFatigue: Double,
        isSelected: Bool
    ) -> UIColor {
        let level = normalizedFatigue.clamped(to: 0...1)
        let base = UIColor(
            hue: 0.30 - (0.30 * level),
            saturation: 0.42 + (0.34 * level),
            brightness: 0.72 + (0.18 * (1 - level)),
            alpha: 1
        )

        guard isSelected else { return base }
        return blended(base, with: .white, ratio: 0.22)
    }

    static func blockColor(
        for muscle: MuscleGroup,
        selected: Bool
    ) -> UIColor {
        let base = muscleColor(for: muscle, alpha: selected ? 1.0 : 0.86)
        guard selected else { return base }
        return blended(base, with: .white, ratio: 0.16)
    }

    private static func blended(_ lhs: UIColor, with rhs: UIColor, ratio: CGFloat) -> UIColor {
        let clamped = max(0, min(1, ratio))
        var lhsRed: CGFloat = 0
        var lhsGreen: CGFloat = 0
        var lhsBlue: CGFloat = 0
        var lhsAlpha: CGFloat = 0
        var rhsRed: CGFloat = 0
        var rhsGreen: CGFloat = 0
        var rhsBlue: CGFloat = 0
        var rhsAlpha: CGFloat = 0

        lhs.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha)
        rhs.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha)

        return UIColor(
            red: lhsRed + ((rhsRed - lhsRed) * clamped),
            green: lhsGreen + ((rhsGreen - lhsGreen) * clamped),
            blue: lhsBlue + ((rhsBlue - lhsBlue) * clamped),
            alpha: lhsAlpha + ((rhsAlpha - lhsAlpha) * clamped)
        )
    }
}

struct VisionBodyPartBlueprint: Sendable {
    enum Primitive: Sendable {
        case box(size: SIMD3<Float>)
        case sphere(radius: Float)
        case cylinder(height: Float, radius: Float)
    }

    let id: String
    let muscle: MuscleGroup
    let primitive: Primitive
    let position: SIMD3<Float>
    let rotationDegrees: SIMD3<Float>
}

@MainActor
enum VisionBodyRig {
    static let blueprints: [VisionBodyPartBlueprint] = buildBlueprints()
    static let bodyRootPosition = SIMD3<Float>(0, -0.05, -1.05)

    static func install(into root: Entity) {
        root.children.removeAll()

        let orbitRoot = Entity()
        orbitRoot.name = "orbit-root"

        let bodyRoot = Entity()
        bodyRoot.name = "body-root"
        bodyRoot.position = bodyRootPosition

        orbitRoot.addChild(bodyRoot)
        root.addChild(orbitRoot)

        installShell(into: bodyRoot)
        installMuscles(into: bodyRoot)
    }

    static func applyVisuals(
        root: Entity,
        muscleLoads: [MuscleGroup: SpatialTrainingSummary.MuscleLoad],
        selectedMuscle: MuscleGroup?,
        yaw: Float,
        pitch: Float
    ) {
        if let orbitRoot = root.findEntity(named: "orbit-root") {
            orbitRoot.orientation = quaternion(yaw: yaw, pitch: pitch)
        }

        for muscle in MuscleGroup.allCases {
            let state = muscleLoads[muscle]
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

            if let rootEntity = root.findEntity(named: "muscle.\(muscle.rawValue)") {
                rootEntity.scale = SIMD3<Float>(repeating: isSelected ? 1.08 : 1.0)
                for child in rootEntity.children.compactMap({ $0 as? ModelEntity }) {
                    if var model = child.model {
                        model.materials = [material]
                        child.model = model
                    }
                }
            }
        }
    }

    private static func installShell(into root: Entity) {
        let shellRoot = Entity()
        shellRoot.name = "body-shell"

        let shellMaterial = SimpleMaterial(
            color: UIColor.white.withAlphaComponent(0.07),
            roughness: 0.42,
            isMetallic: false
        )
        let shellParts: [(mesh: MeshResource, position: SIMD3<Float>, rotation: SIMD3<Float>)] = [
            (.generateSphere(radius: 0.13), [0, 0.73, 0], .zero),
            (.generateCylinder(height: 0.46, radius: 0.22), [0, 0.33, 0], .zero),
            (.generateBox(size: [0.34, 0.18, 0.20]), [0, -0.01, 0], .zero),
            (.generateCylinder(height: 0.46, radius: 0.07), [-0.33, 0.26, 0], [0, 0, 14]),
            (.generateCylinder(height: 0.46, radius: 0.07), [0.33, 0.26, 0], [0, 0, -14]),
            (.generateCylinder(height: 0.34, radius: 0.055), [-0.36, -0.12, 0], [0, 0, 8]),
            (.generateCylinder(height: 0.34, radius: 0.055), [0.36, -0.12, 0], [0, 0, -8]),
            (.generateCylinder(height: 0.58, radius: 0.11), [-0.13, -0.55, 0], .zero),
            (.generateCylinder(height: 0.58, radius: 0.11), [0.13, -0.55, 0], .zero),
            (.generateCylinder(height: 0.44, radius: 0.08), [-0.13, -1.02, 0], .zero),
            (.generateCylinder(height: 0.44, radius: 0.08), [0.13, -1.02, 0], .zero),
        ]

        for (index, part) in shellParts.enumerated() {
            let entity = ModelEntity(mesh: part.mesh, materials: [shellMaterial])
            entity.name = "shell-\(index)"
            entity.position = part.position
            entity.orientation = quaternion(fromDegrees: part.rotation)
            shellRoot.addChild(entity)
        }

        root.addChild(shellRoot)
    }

    private static func installMuscles(into root: Entity) {
        let groupedBlueprints = Dictionary(grouping: blueprints, by: \.muscle)

        for muscle in MuscleGroup.allCases {
            let muscleRoot = Entity()
            muscleRoot.name = "muscle.\(muscle.rawValue)"

            for blueprint in groupedBlueprints[muscle] ?? [] {
                let entity = makeModelEntity(for: blueprint)
                muscleRoot.addChild(entity)
            }

            root.addChild(muscleRoot)
        }
    }

    private static func makeModelEntity(for blueprint: VisionBodyPartBlueprint) -> ModelEntity {
        let mesh: MeshResource
        switch blueprint.primitive {
        case .box(let size):
            mesh = .generateBox(size: size)
        case .sphere(let radius):
            mesh = .generateSphere(radius: radius)
        case .cylinder(let height, let radius):
            mesh = .generateCylinder(height: height, radius: radius)
        }

        let entity = ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.24), isMetallic: false)]
        )
        entity.name = blueprint.id
        entity.position = blueprint.position
        entity.orientation = quaternion(fromDegrees: blueprint.rotationDegrees)
        return entity
    }

    private static func quaternion(yaw: Float, pitch: Float) -> simd_quatf {
        let yawRotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        let pitchRotation = simd_quatf(angle: pitch, axis: [1, 0, 0])
        return yawRotation * pitchRotation
    }

    private static func quaternion(fromDegrees degrees: SIMD3<Float>) -> simd_quatf {
        let radians = degrees * (.pi / 180)
        let qx = simd_quatf(angle: radians.x, axis: [1, 0, 0])
        let qy = simd_quatf(angle: radians.y, axis: [0, 1, 0])
        let qz = simd_quatf(angle: radians.z, axis: [0, 0, 1])
        return qz * qy * qx
    }

    private static func buildBlueprints() -> [VisionBodyPartBlueprint] {
        chestParts +
        shoulderParts +
        bicepsParts +
        tricepsParts +
        forearmParts +
        coreParts +
        backParts +
        latsParts +
        trapsParts +
        gluteParts +
        quadricepsParts +
        hamstringParts +
        calfParts
    }

    private static var chestParts: [VisionBodyPartBlueprint] {
        mirroredBoxes(prefix: "chest", muscle: .chest, x: 0.13, y: 0.36, z: 0.18, size: [0.19, 0.16, 0.08])
    }

    private static var shoulderParts: [VisionBodyPartBlueprint] {
        mirroredSpheres(prefix: "shoulders", muscle: .shoulders, x: 0.31, y: 0.40, z: 0.02, radius: 0.10)
    }

    private static var bicepsParts: [VisionBodyPartBlueprint] {
        mirroredCapsules(prefix: "biceps", muscle: .biceps, x: 0.36, y: 0.18, z: 0.13, height: 0.24, radius: 0.055, rotationDegrees: [0, 0, 12])
    }

    private static var tricepsParts: [VisionBodyPartBlueprint] {
        mirroredCapsules(prefix: "triceps", muscle: .triceps, x: 0.37, y: 0.16, z: -0.12, height: 0.26, radius: 0.055, rotationDegrees: [0, 0, 8])
    }

    private static var forearmParts: [VisionBodyPartBlueprint] {
        mirroredCapsules(prefix: "forearms", muscle: .forearms, x: 0.41, y: -0.14, z: 0.04, height: 0.26, radius: 0.044, rotationDegrees: [0, 0, 6])
    }

    private static var coreParts: [VisionBodyPartBlueprint] {
        [
            .init(
                id: "core-center",
                muscle: .core,
                primitive: .box(size: [0.24, 0.28, 0.08]),
                position: [0, 0.06, 0.17],
                rotationDegrees: .zero
            )
        ]
    }

    private static var backParts: [VisionBodyPartBlueprint] {
        [
            .init(
                id: "back-center",
                muscle: .back,
                primitive: .box(size: [0.28, 0.30, 0.09]),
                position: [0, 0.07, -0.17],
                rotationDegrees: .zero
            )
        ]
    }

    private static var latsParts: [VisionBodyPartBlueprint] {
        mirroredBoxes(prefix: "lats", muscle: .lats, x: 0.18, y: 0.10, z: -0.17, size: [0.10, 0.24, 0.08])
    }

    private static var trapsParts: [VisionBodyPartBlueprint] {
        [
            .init(
                id: "traps-center",
                muscle: .traps,
                primitive: .box(size: [0.22, 0.10, 0.07]),
                position: [0, 0.49, -0.08],
                rotationDegrees: .zero
            )
        ]
    }

    private static var gluteParts: [VisionBodyPartBlueprint] {
        mirroredBoxes(prefix: "glutes", muscle: .glutes, x: 0.12, y: -0.18, z: -0.12, size: [0.15, 0.14, 0.08])
    }

    private static var quadricepsParts: [VisionBodyPartBlueprint] {
        mirroredCapsules(prefix: "quadriceps", muscle: .quadriceps, x: 0.13, y: -0.54, z: 0.12, height: 0.44, radius: 0.075, rotationDegrees: .zero)
    }

    private static var hamstringParts: [VisionBodyPartBlueprint] {
        mirroredCapsules(prefix: "hamstrings", muscle: .hamstrings, x: 0.13, y: -0.56, z: -0.11, height: 0.44, radius: 0.075, rotationDegrees: .zero)
    }

    private static var calfParts: [VisionBodyPartBlueprint] {
        mirroredCapsules(prefix: "calves", muscle: .calves, x: 0.13, y: -1.01, z: -0.05, height: 0.32, radius: 0.055, rotationDegrees: .zero)
    }

    private static func mirroredBoxes(
        prefix: String,
        muscle: MuscleGroup,
        x: Float,
        y: Float,
        z: Float,
        size: SIMD3<Float>
    ) -> [VisionBodyPartBlueprint] {
        [
            .init(
                id: "\(prefix)-left",
                muscle: muscle,
                primitive: .box(size: size),
                position: [-x, y, z],
                rotationDegrees: .zero
            ),
            .init(
                id: "\(prefix)-right",
                muscle: muscle,
                primitive: .box(size: size),
                position: [x, y, z],
                rotationDegrees: .zero
            ),
        ]
    }

    private static func mirroredSpheres(
        prefix: String,
        muscle: MuscleGroup,
        x: Float,
        y: Float,
        z: Float,
        radius: Float
    ) -> [VisionBodyPartBlueprint] {
        [
            .init(
                id: "\(prefix)-left",
                muscle: muscle,
                primitive: .sphere(radius: radius),
                position: [-x, y, z],
                rotationDegrees: .zero
            ),
            .init(
                id: "\(prefix)-right",
                muscle: muscle,
                primitive: .sphere(radius: radius),
                position: [x, y, z],
                rotationDegrees: .zero
            ),
        ]
    }

    private static func mirroredCapsules(
        prefix: String,
        muscle: MuscleGroup,
        x: Float,
        y: Float,
        z: Float,
        height: Float,
        radius: Float,
        rotationDegrees: SIMD3<Float>
    ) -> [VisionBodyPartBlueprint] {
        [
            .init(
                id: "\(prefix)-left",
                muscle: muscle,
                primitive: .cylinder(height: height, radius: radius),
                position: [-x, y, z],
                rotationDegrees: rotationDegrees
            ),
            .init(
                id: "\(prefix)-right",
                muscle: muscle,
                primitive: .cylinder(height: height, radius: radius),
                position: [x, y, z],
                rotationDegrees: [rotationDegrees.x, rotationDegrees.y, -rotationDegrees.z]
            ),
        ]
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
