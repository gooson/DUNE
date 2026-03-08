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
    static let defaultShellOpacity: Float = 0.06
    static let volumeAnimationDuration: TimeInterval = 0.35

    /// Non-uniform scale per volume intensity — X/Z expand more than Y for "bulk" look
    static func volumeScale(for intensity: MuscleMap3DVolumeIntensity) -> SIMD3<Float> {
        switch intensity {
        case .none:     SIMD3<Float>(1.0, 1.0, 1.0)
        case .light:    SIMD3<Float>(1.02, 1.01, 1.02)
        case .moderate: SIMD3<Float>(1.05, 1.02, 1.05)
        case .high:     SIMD3<Float>(1.09, 1.03, 1.09)
        case .veryHigh: SIMD3<Float>(1.14, 1.04, 1.14)
        }
    }

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
        guard entityName.hasPrefix("muscle_") else { return nil }
        let rawValue = String(entityName.dropFirst("muscle_".count))
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

@MainActor
final class MuscleMap3DScene {
    let anchor = AnchorEntity(world: SIMD3<Float>.zero)

    private let orbitRoot = Entity()
    private let bodyRoot = Entity()
    private var shellModels: [ModelEntity] = []
    private var muscleRoots: [MuscleGroup: Entity] = [:]
    private var muscleModels: [MuscleGroup: [ModelEntity]] = [:]
    private var hasPreparedGeometry = false

    init() {
        bodyRoot.position = [0, -0.05, -1.25]
        orbitRoot.addChild(bodyRoot)
        anchor.addChild(orbitRoot)
    }

    var isReady: Bool {
        hasPreparedGeometry
    }

    func prepareIfNeeded() async {
        guard !hasPreparedGeometry else { return }

        guard let rootEntity = loadUSDZEntity() else {
            AppLogger.ui.error("[MuscleMap3D] Failed to load muscle_body.usdz")
            return
        }

        installBodyShell(from: rootEntity)

        for muscle in MuscleGroup.allCases {
            let entityName = "muscle_\(muscle.rawValue)"
            guard let usdzEntity = rootEntity.findEntity(named: entityName) else {
                AppLogger.ui.warning("[MuscleMap3D] Missing USDZ entity: \(entityName)")
                continue
            }

            let root = usdzEntity.clone(recursive: true)
            root.name = entityName

            let models = collectModelEntities(from: root)
            if models.isEmpty {
                AppLogger.ui.warning("[MuscleMap3D] No ModelEntity children for: \(entityName)")
            }
            for model in models {
                model.components.set(InputTargetComponent())
            }
            muscleModels[muscle] = models

            root.generateCollisionShapes(recursive: true)
            bodyRoot.addChild(root)
            muscleRoots[muscle] = root
        }

        hasPreparedGeometry = true
    }

    func applyInteractionTransform(yaw: Float, pitch: Float, zoomScale: Float) {
        let yawRotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        let pitchRotation = simd_quatf(angle: pitch, axis: [1, 0, 0])
        orbitRoot.orientation = yawRotation * pitchRotation
        orbitRoot.scale = SIMD3<Float>(repeating: zoomScale)
    }

    private var lastFatigueHash: Int = 0
    private var lastMuscleMode: MuscleMap3DMode?
    private var lastSelectedMuscle: MuscleGroup?
    private var lastMuscleColorScheme: ColorScheme?

    func updateVisuals(
        fatigueStates: [MuscleFatigueState],
        mode: MuscleMap3DMode,
        selectedMuscle: MuscleGroup?,
        colorScheme: ColorScheme,
        shellOpacity: Float = MuscleMap3DState.defaultShellOpacity
    ) {
        updateShellMaterials(colorScheme: colorScheme, opacity: shellOpacity)

        var hasher = Hasher()
        for state in fatigueStates {
            hasher.combine(state.muscle)
            hasher.combine(state.fatigueLevel)
            hasher.combine(state.weeklyVolume)
        }
        let fatigueHash = hasher.finalize()

        let muscleInputsChanged = fatigueHash != lastFatigueHash
            || mode != lastMuscleMode
            || selectedMuscle != lastSelectedMuscle
            || colorScheme != lastMuscleColorScheme
        guard muscleInputsChanged else { return }
        lastFatigueHash = fatigueHash
        lastMuscleMode = mode
        lastSelectedMuscle = selectedMuscle
        lastMuscleColorScheme = colorScheme

        let fatigueByMuscle = Dictionary(
            uniqueKeysWithValues: fatigueStates.map { ($0.muscle, $0) }
        )

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

            guard let root = muscleRoots[muscle] else { continue }

            let volumeScale: SIMD3<Float>
            if case .volume(let intensity) = displayState {
                volumeScale = MuscleMap3DState.volumeScale(for: intensity)
            } else {
                volumeScale = SIMD3<Float>(repeating: 1.0)
            }

            let selectionMultiplier = isSelected ? MuscleMap3DState.selectedScale : Float(1.0)
            let finalScale = volumeScale * selectionMultiplier

            let target = Transform(
                scale: finalScale,
                rotation: root.orientation,
                translation: root.position
            )
            root.move(
                to: target,
                relativeTo: root.parent,
                duration: MuscleMap3DState.volumeAnimationDuration
            )
        }
    }

    // MARK: - Public Accessors

    func muscleModelEntities(for muscle: MuscleGroup) -> [ModelEntity] {
        muscleModels[muscle] ?? []
    }

    func muscleEntity(for muscle: MuscleGroup) -> Entity? {
        muscleRoots[muscle]
    }

    var shellModelEntities: [ModelEntity] { shellModels }

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

    // MARK: - USDZ Loading

    private func loadUSDZEntity() -> Entity? {
        guard let url = Bundle.main.url(forResource: "muscle_body", withExtension: "usdz") else {
            AppLogger.ui.error("[MuscleMap3D] muscle_body.usdz not found in bundle")
            return nil
        }
        do {
            return try Entity.load(contentsOf: url)
        } catch {
            AppLogger.ui.error("[MuscleMap3D] USDZ load error: \(error.localizedDescription)")
            return nil
        }
    }

    private func installBodyShell(from rootEntity: Entity) {
        guard let shell = rootEntity.findEntity(named: "body_shell") else {
            AppLogger.ui.warning("[MuscleMap3D] Missing body_shell entity in USDZ")
            return
        }
        let shellClone = shell.clone(recursive: true)
        shellClone.name = "body-shell"
        shellModels = collectModelEntities(from: shellClone)
        bodyRoot.addChild(shellClone)
    }

    private func collectModelEntities(from root: Entity) -> [ModelEntity] {
        var models: [ModelEntity] = []
        var queue: [Entity] = [root]
        while !queue.isEmpty {
            let entity = queue.removeFirst()
            if let model = entity as? ModelEntity {
                models.append(model)
            }
            queue.append(contentsOf: entity.children)
        }
        return models
    }

    // MARK: - Materials

    private var lastShellOpacity: Float = -1
    private var lastShellColorScheme: ColorScheme?

    private func updateShellMaterials(colorScheme: ColorScheme, opacity: Float) {
        guard opacity != lastShellOpacity || colorScheme != lastShellColorScheme else { return }
        lastShellOpacity = opacity
        lastShellColorScheme = colorScheme

        let alpha = CGFloat(opacity)
        let tint: UIColor = colorScheme == .dark
            ? UIColor.white.withAlphaComponent(alpha)
            : UIColor.black.withAlphaComponent(alpha)
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

    private static let recoverySpecs: [(hue: CGFloat, sat: CGFloat, darkB: CGFloat, lightB: CGFloat)] = [
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

    private func recoveryColor(
        for fatigueLevel: FatigueLevel,
        colorScheme: ColorScheme
    ) -> UIColor {
        if fatigueLevel == .noData {
            return colorScheme == .dark
                ? UIColor(white: 0.46, alpha: 0.52)
                : UIColor(white: 0.76, alpha: 0.82)
        }

        let index = Int(fatigueLevel.rawValue)
        guard Self.recoverySpecs.indices.contains(index) else {
            return colorScheme == .dark
                ? UIColor(white: 0.46, alpha: 0.52)
                : UIColor(white: 0.76, alpha: 0.82)
        }
        let spec = Self.recoverySpecs[index]
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
