import SwiftUI
import RealityKit
import UIKit

enum MuscleMap3DMode: String, CaseIterable, Sendable {
    case recovery
    case volume

    var label: String {
        switch self {
        case .recovery:
            String(localized: "Recovery")
        case .volume:
            String(localized: "Volume")
        }
    }
}

enum MuscleMap3DVolumeIntensity: Int, CaseIterable, Sendable {
    case none = 0
    case light = 1
    case moderate = 2
    case high = 3
    case veryHigh = 4

    static func from(sets: Int) -> MuscleMap3DVolumeIntensity {
        switch sets {
        case 0: .none
        case 1...5: .light
        case 6...10: .moderate
        case 11...15: .high
        default: .veryHigh
        }
    }

    var description: String {
        switch self {
        case .none:
            String(localized: "No training this week, training needed")
        case .light:
            String(localized: "Light stimulus, can add volume")
        case .moderate:
            String(localized: "Adequate volume, maintain or slight increase")
        case .high:
            String(localized: "High volume, check recovery status")
        case .veryHigh:
            String(localized: "Very high volume, watch for overtraining")
        }
    }
}

enum MuscleMap3DDisplayState: Equatable, Sendable {
    case noData
    case recovery(FatigueLevel)
    case volume(MuscleMap3DVolumeIntensity)
}

enum MuscleMap3DState {
    static let defaultYaw: Float = 0.28
    static let minZoomScale: Float = 0.82
    static let maxZoomScale: Float = 1.45
    static let defaultPitch: Float = -0.18
    static let minPitch: Float = -0.52
    static let maxPitch: Float = 0.22
    static let rotationSensitivity: Float = 0.01
    static let pitchSensitivity: Float = 0.006
    static let selectedScale: Float = 1.045

    static func clampedZoomScale(_ scale: Float) -> Float {
        Swift.max(minZoomScale, Swift.min(scale, maxZoomScale))
    }

    static func clampedPitch(_ pitch: Float) -> Float {
        Swift.max(minPitch, Swift.min(pitch, maxPitch))
    }

    static func normalizedYaw(_ yaw: Float) -> Float {
        let rawDegrees = yaw * 180 / .pi
        let remainder = rawDegrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    static func preferredYaw(for muscle: MuscleGroup) -> Float {
        switch muscle {
        case .back, .lats, .traps, .glutes, .hamstrings, .calves:
            .pi + 0.12
        case .triceps:
            .pi - 0.28
        default:
            defaultYaw
        }
    }

    static func defaultSelectedMuscle(
        highlighted: MuscleGroup?,
        fatigueStates: [MuscleFatigueState]
    ) -> MuscleGroup {
        if let highlighted {
            return highlighted
        }

        if let best = fatigueStates.max(by: prioritySort) {
            return best.muscle
        }

        return .chest
    }

    static func displayState(
        for muscle: MuscleGroup?,
        fatigueByMuscle: [MuscleGroup: MuscleFatigueState],
        mode: MuscleMap3DMode
    ) -> MuscleMap3DDisplayState {
        guard let muscle else { return .noData }
        guard let state = fatigueByMuscle[muscle] else { return .noData }

        switch mode {
        case .recovery:
            return .recovery(state.fatigueLevel)
        case .volume:
            return .volume(MuscleMap3DVolumeIntensity.from(sets: state.weeklyVolume))
        }
    }

    static func muscle(from entityName: String) -> MuscleGroup? {
        guard entityName.hasPrefix("muscle.") else { return nil }
        let rawValue = String(entityName.dropFirst("muscle.".count))
        return MuscleGroup(rawValue: rawValue)
    }

    private static func prioritySort(lhs: MuscleFatigueState, rhs: MuscleFatigueState) -> Bool {
        if lhs.weeklyVolume != rhs.weeklyVolume {
            return lhs.weeklyVolume < rhs.weeklyVolume
        }
        if lhs.fatigueLevel != rhs.fatigueLevel {
            return lhs.fatigueLevel < rhs.fatigueLevel
        }
        return lhs.muscle.rawValue < rhs.muscle.rawValue
    }
}

struct MuscleMap3DPartDescriptor: Sendable {
    enum Plane: String, Sendable {
        case front
        case back
    }

    let id: String
    let muscle: MuscleGroup
    let plane: Plane
    let depth: Float
    let zOffset: Float
    let segmentCount: Int
}

enum MuscleMap3DGeometry {
    static let bodyHeight: CGFloat = 1.72
    static let frontLayerZ: Float = 0.07
    static let backLayerZ: Float = -0.07

    static let descriptors: [String: MuscleMap3DPartDescriptor] = {
        Dictionary(uniqueKeysWithValues: buildEntries().map { ($0.descriptor.id, $0.descriptor) })
    }()

    static let allEntries: [(part: MuscleBodyPart, descriptor: MuscleMap3DPartDescriptor)] = buildEntries()

    static func normalizedPath(for part: MuscleBodyPart) -> Path {
        let viewBox = MuscleMapData.svgFrontViewBox
        let scale = bodyHeight / viewBox.height

        let centered = part.cachedPath.applying(
            CGAffineTransform(
                translationX: -(part.xOffset + (viewBox.width / 2)),
                y: -(viewBox.height / 2)
            )
        )

        return centered.applying(CGAffineTransform(scaleX: scale, y: -scale))
    }

    static func descriptor(for entityName: String) -> MuscleMap3DPartDescriptor? {
        descriptors[entityName]
    }

    private static func buildEntries() -> [(part: MuscleBodyPart, descriptor: MuscleMap3DPartDescriptor)] {
        let frontEntries = MuscleMapData.svgFrontParts.map { part in
            (
                part: part,
                descriptor: descriptor(
                    id: part.id,
                    muscle: part.muscle,
                    plane: .front
                )
            )
        }

        let backEntries = MuscleMapData.svgBackParts.map { part in
            (
                part: part,
                descriptor: descriptor(
                    id: part.id,
                    muscle: part.muscle,
                    plane: .back
                )
            )
        }

        return frontEntries + backEntries
    }

    private static func descriptor(
        id: String,
        muscle: MuscleGroup,
        plane: MuscleMap3DPartDescriptor.Plane
    ) -> MuscleMap3DPartDescriptor {
        MuscleMap3DPartDescriptor(
            id: id,
            muscle: muscle,
            plane: plane,
            depth: depth(for: muscle),
            zOffset: plane == .front ? frontLayerZ : backLayerZ,
            segmentCount: segmentCount(for: muscle)
        )
    }

    private static func depth(for muscle: MuscleGroup) -> Float {
        switch muscle {
        case .chest, .back, .quadriceps, .hamstrings, .glutes, .lats:
            0.075
        case .shoulders, .triceps, .biceps, .traps, .core:
            0.062
        case .forearms, .calves:
            0.05
        }
    }

    private static func segmentCount(for muscle: MuscleGroup) -> Int {
        switch muscle {
        case .forearms, .triceps, .biceps, .traps, .calves:
            28
        default:
            36
        }
    }
}

@MainActor
final class MuscleMap3DMeshCache {
    static let shared = MuscleMap3DMeshCache()

    private var meshes: [String: MeshResource] = [:]

    func mesh(
        for part: MuscleBodyPart,
        descriptor: MuscleMap3DPartDescriptor
    ) async throws -> MeshResource {
        if let mesh = meshes[descriptor.id] {
            return mesh
        }

        var options = MeshResource.ShapeExtrusionOptions()
        options.boundaryResolution = .uniformSegmentsPerSpan(segmentCount: descriptor.segmentCount)
        options.extrusionMethod = .linear(depth: descriptor.depth)
        options.chamferMode = .front

        let mesh = try await MeshResource(
            extruding: MuscleMap3DGeometry.normalizedPath(for: part),
            extrusionOptions: options
        )
        meshes[descriptor.id] = mesh
        return mesh
    }
}

@MainActor
final class MuscleMap3DScene {
    static let partDescriptors = MuscleMap3DGeometry.descriptors

    let anchor = AnchorEntity(world: SIMD3<Float>.zero)

    private let orbitRoot = Entity()
    private let bodyRoot = Entity()
    private let meshCache = MuscleMap3DMeshCache.shared
    private var shellModels: [ModelEntity] = []
    private var muscleRoots: [MuscleGroup: Entity] = [:]
    private var muscleModels: [MuscleGroup: [ModelEntity]] = [:]
    private var hasPreparedGeometry = false

    init() {
        bodyRoot.position = [0, -0.05, -1.25]
        orbitRoot.addChild(bodyRoot)
        anchor.addChild(orbitRoot)

        installBodyShell()
    }

    var isReady: Bool {
        hasPreparedGeometry
    }

    #if !os(visionOS)
    func installIfNeeded(in view: ARView) {
        guard anchor.scene == nil else { return }
        view.scene.anchors.append(anchor)
    }
    #endif

    func prepareIfNeeded() async {
        guard !hasPreparedGeometry else { return }
        hasPreparedGeometry = true

        let groupedEntries = Dictionary(grouping: MuscleMap3DGeometry.allEntries, by: \.descriptor.muscle)

        for muscle in MuscleGroup.allCases {
            let root = Entity()
            root.name = "muscle.\(muscle.rawValue)"
            root.components.set(InputTargetComponent())

            for entry in groupedEntries[muscle] ?? [] {
                guard let entity = await makeModelEntity(
                    for: entry.part,
                    descriptor: entry.descriptor
                ) else { continue }
                root.addChild(entity)
                muscleModels[muscle, default: []].append(entity)
            }

            root.generateCollisionShapes(recursive: true)
            bodyRoot.addChild(root)
            muscleRoots[muscle] = root
        }
    }

    func applyInteractionTransform(yaw: Float, pitch: Float, zoomScale: Float) {
        let yawRotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        let pitchRotation = simd_quatf(angle: pitch, axis: [1, 0, 0])
        orbitRoot.orientation = yawRotation * pitchRotation
        orbitRoot.scale = SIMD3<Float>(repeating: zoomScale)
    }

    func updateVisuals(
        fatigueStates: [MuscleFatigueState],
        mode: MuscleMap3DMode,
        selectedMuscle: MuscleGroup?,
        colorScheme: ColorScheme
    ) {
        let fatigueByMuscle = Dictionary(
            uniqueKeysWithValues: fatigueStates.map { ($0.muscle, $0) }
        )

        updateShellMaterials(colorScheme: colorScheme)

        for muscle in MuscleGroup.allCases {
            let displayState = MuscleMap3DState.displayState(
                for: muscle,
                fatigueByMuscle: fatigueByMuscle,
                mode: mode
            )
            let isSelected = muscle == selectedMuscle
            let material = SimpleMaterial(
                color: resolvedColor(
                    for: displayState,
                    colorScheme: colorScheme,
                    isSelected: isSelected
                ),
                roughness: isSelected ? 0.15 : 0.32,
                isMetallic: false
            )

            for model in muscleModels[muscle] ?? [] {
                if var modelComponent = model.model {
                    modelComponent.materials = [material]
                    model.model = modelComponent
                }
            }

            muscleRoots[muscle]?.scale = SIMD3<Float>(
                repeating: isSelected ? MuscleMap3DState.selectedScale : 1
            )
        }
    }

    func muscle(for entity: Entity) -> MuscleGroup? {
        var current: Entity? = entity

        while let node = current {
            if let muscle = MuscleMap3DState.muscle(from: node.name) {
                return muscle
            }
            current = node.parent
        }

        return nil
    }

    private func installBodyShell() {
        let shellRoot = Entity()
        shellRoot.name = "body-shell"

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
            let entity = ModelEntity(mesh: part.mesh, materials: [])
            entity.name = "shell-\(index)"
            entity.position = part.position
            entity.orientation = quaternion(fromDegrees: part.rotation)
            shellRoot.addChild(entity)
            shellModels.append(entity)
        }

        bodyRoot.addChild(shellRoot)
    }

    private func makeModelEntity(
        for part: MuscleBodyPart,
        descriptor: MuscleMap3DPartDescriptor
    ) async -> ModelEntity? {
        do {
            let mesh = try await meshCache.mesh(for: part, descriptor: descriptor)
            let entity = ModelEntity(mesh: mesh, materials: [])
            entity.name = descriptor.id
            entity.position = [0, 0, descriptor.zOffset]
            if descriptor.plane == .back {
                entity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            }
            entity.components.set(InputTargetComponent())
            entity.generateCollisionShapes(recursive: false)
            return entity
        } catch {
            AppLogger.ui.error("Muscle 3D mesh extrusion failed for \(descriptor.id): \(error.localizedDescription)")
            return nil
        }
    }

    private func updateShellMaterials(colorScheme: ColorScheme) {
        let tint: UIColor = colorScheme == .dark
            ? UIColor.white.withAlphaComponent(0.05)
            : UIColor.black.withAlphaComponent(0.06)
        let material = SimpleMaterial(color: tint, roughness: 0.4, isMetallic: false)

        for model in shellModels {
            if var modelComponent = model.model {
                modelComponent.materials = [material]
                model.model = modelComponent
            }
        }
    }

    private func resolvedColor(
        for displayState: MuscleMap3DDisplayState,
        colorScheme: ColorScheme,
        isSelected: Bool
    ) -> UIColor {
        let base: UIColor

        switch displayState {
        case .noData:
            base = colorScheme == .dark
                ? UIColor(white: 0.46, alpha: 0.52)
                : UIColor(white: 0.76, alpha: 0.82)
        case .recovery(let fatigueLevel):
            base = recoveryColor(for: fatigueLevel, colorScheme: colorScheme)
        case .volume(let intensity):
            base = volumeColor(for: intensity, colorScheme: colorScheme)
        }

        guard isSelected else { return base }
        return blended(base, with: .white, ratio: 0.2)
    }

    private func recoveryColor(
        for fatigueLevel: FatigueLevel,
        colorScheme: ColorScheme
    ) -> UIColor {
        if fatigueLevel == .noData {
            return colorScheme == .dark
                ? UIColor(white: 0.46, alpha: 0.52)
                : UIColor(white: 0.76, alpha: 0.82)
        }

        let specs: [(hue: CGFloat, sat: CGFloat, darkB: CGFloat, lightB: CGFloat)] = [
            (0, 0, 0, 0),
            (0.28, 0.30, 0.75, 0.55),
            (0.25, 0.32, 0.78, 0.58),
            (0.20, 0.35, 0.80, 0.62),
            (0.14, 0.38, 0.82, 0.65),
            (0.10, 0.42, 0.82, 0.68),
            (0.07, 0.45, 0.80, 0.65),
            (0.05, 0.48, 0.75, 0.60),
            (0.03, 0.50, 0.70, 0.55),
            (0.01, 0.52, 0.65, 0.50),
            (0.00, 0.55, 0.58, 0.45),
        ]
        let spec = specs[Int(fatigueLevel.rawValue)]
        return UIColor(
            hue: spec.hue,
            saturation: spec.sat,
            brightness: colorScheme == .dark ? spec.darkB : spec.lightB,
            alpha: 1
        )
    }

    private func volumeColor(
        for intensity: MuscleMap3DVolumeIntensity,
        colorScheme: ColorScheme
    ) -> UIColor {
        switch intensity {
        case .none:
            return colorScheme == .dark
                ? UIColor(white: 0.46, alpha: 0.52)
                : UIColor(white: 0.76, alpha: 0.82)
        case .light:
            return UIColor(red: 0.65, green: 0.53, blue: 0.38, alpha: 0.85)
        case .moderate:
            return UIColor(red: 0.76, green: 0.50, blue: 0.30, alpha: 0.9)
        case .high:
            return UIColor(red: 0.84, green: 0.42, blue: 0.24, alpha: 0.95)
        case .veryHigh:
            return UIColor(red: 0.92, green: 0.34, blue: 0.18, alpha: 1)
        }
    }

    private func quaternion(fromDegrees degrees: SIMD3<Float>) -> simd_quatf {
        let radians = degrees * (.pi / 180)
        let qx = simd_quatf(angle: radians.x, axis: [1, 0, 0])
        let qy = simd_quatf(angle: radians.y, axis: [0, 1, 0])
        let qz = simd_quatf(angle: radians.z, axis: [0, 0, 1])
        return qz * qy * qx
    }

    private func blended(_ lhs: UIColor, with rhs: UIColor, ratio: CGFloat) -> UIColor {
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
