import RealityKit
import SwiftUI
import UIKit

/// Actual 3D muscle map built with a procedural RealityKit body rig.
struct MuscleMap3DView: View {
    let fatigueStates: [MuscleFatigueState]
    let highlightedMuscle: MuscleGroup?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var mode: MuscleMap3DMode = .recovery
    @State private var selectedMuscle: MuscleGroup?
    @State private var resetToken = 0

    init(fatigueStates: [MuscleFatigueState], highlightedMuscle: MuscleGroup?) {
        self.fatigueStates = fatigueStates
        self.highlightedMuscle = highlightedMuscle
        _selectedMuscle = State(initialValue: highlightedMuscle)
    }

    private var fatigueByMuscle: [MuscleGroup: MuscleFatigueState] {
        Dictionary(uniqueKeysWithValues: fatigueStates.map { ($0.muscle, $0) })
    }

    private var selectedState: MuscleMap3DDisplayState {
        MuscleMap3DState.displayState(
            for: selectedMuscle,
            fatigueByMuscle: fatigueByMuscle,
            mode: mode
        )
    }

    private var selectedFatigueState: MuscleFatigueState? {
        guard let selectedMuscle else { return nil }
        return fatigueByMuscle[selectedMuscle]
    }

    private var viewerHeight: CGFloat {
        sizeClass == .regular ? 560 : 430
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                summaryCard

                Picker("Mode", selection: $mode) {
                    ForEach(MuscleMap3DMode.allCases, id: \.rawValue) { currentMode in
                        Text(currentMode.label).tag(currentMode)
                    }
                }
                .pickerStyle(.segmented)

                MuscleMap3DViewer(
                    fatigueStates: fatigueStates,
                    mode: mode,
                    colorScheme: colorScheme,
                    selectedMuscle: $selectedMuscle,
                    resetToken: resetToken
                )
                .frame(height: viewerHeight)
                .frame(maxWidth: .infinity)
                .background(viewerBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }

                muscleSelectionStrip
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Muscle Map 3D")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Reset")) {
                    withAnimation(DS.Animation.snappy) {
                        resetToken += 1
                    }
                }
            }
        }
        .onAppear {
            if selectedMuscle == nil {
                selectedMuscle = MuscleMap3DState.defaultSelectedMuscle(
                    highlighted: highlightedMuscle,
                    fatigueStates: fatigueStates
                )
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: selectedMuscle?.iconName ?? "figure.strengthtraining.traditional")
                    .font(.headline)
                    .foregroundStyle(DS.Color.activity)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(selectedMuscle?.displayName ?? String(localized: "No Data"))
                        .font(.title3.weight(.semibold))
                    Text(summaryValue(for: selectedState))
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: DS.Spacing.md) {
                metricTile(
                    title: mode == .recovery ? String(localized: "Recovery") : String(localized: "Weekly Volume"),
                    value: primaryMetricValue
                )
                metricTile(
                    title: mode == .recovery ? String(localized: "Weekly Volume") : String(localized: "Recovery"),
                    value: secondaryMetricValue
                )
            }
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var primaryMetricValue: String {
        switch selectedState {
        case .noData:
            String(localized: "No Data")
        case .recovery(let fatigueLevel):
            fatigueLevel.displayName
        case .volume:
            selectedFatigueState?.weeklyVolume.formatted() ?? "0"
        }
    }

    private var secondaryMetricValue: String {
        guard let selectedFatigueState else {
            return String(localized: "No Data")
        }

        switch mode {
        case .recovery:
            return selectedFatigueState.weeklyVolume.formatted()
        case .volume:
            return selectedFatigueState.fatigueLevel.displayName
        }
    }

    private func summaryValue(for state: MuscleMap3DDisplayState) -> String {
        switch state {
        case .noData:
            return String(localized: "No Data")
        case .recovery(let fatigueLevel):
            return fatigueLevel.displayName
        case .volume(let intensity):
            return intensity.description
        }
    }

    private var viewerBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.lg)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08),
                        DS.Color.activity.opacity(colorScheme == .dark ? 0.22 : 0.12),
                        Color.black.opacity(colorScheme == .dark ? 0.32 : 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var muscleSelectionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    Button {
                        selectedMuscle = muscle
                    } label: {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: muscle.iconName)
                                .font(.caption2)
                            Text(muscle.displayName)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            (selectedMuscle == muscle ? DS.Color.activity.opacity(0.22) : Color.white.opacity(0.05)),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    selectedMuscle == muscle ? DS.Color.activity.opacity(0.4) : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }
}

enum MuscleMap3DMode: Int, CaseIterable, Sendable {
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

enum MuscleMap3DDisplayState: Equatable, Sendable {
    case noData
    case recovery(FatigueLevel)
    case volume(VolumeIntensity)
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
    static let selectedScale: Float = 1.06

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
            return .volume(VolumeIntensity.from(sets: state.weeklyVolume))
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

struct MuscleMap3DPartBlueprint: Sendable {
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
final class MuscleMap3DScene {
    static let partBlueprints: [MuscleMap3DPartBlueprint] = buildBlueprints()

    private let anchor = AnchorEntity(world: SIMD3<Float>.zero)
    private let orbitRoot = Entity()
    private let bodyRoot = Entity()
    private var shellModels: [ModelEntity] = []
    private var muscleRoots: [MuscleGroup: Entity] = [:]
    private var muscleModels: [MuscleGroup: [ModelEntity]] = [:]

    init() {
        bodyRoot.position = [0, -0.05, -1.25]
        orbitRoot.addChild(bodyRoot)
        anchor.addChild(orbitRoot)

        installBodyShell()
        installMuscleGroups()
    }

    func installIfNeeded(in view: ARView) {
        guard anchor.scene == nil else { return }
        view.scene.anchors.append(anchor)
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
                roughness: isSelected ? 0.2 : 0.34,
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

    private func installMuscleGroups() {
        let groupedBlueprints = Dictionary(grouping: Self.partBlueprints, by: \.muscle)

        for muscle in MuscleGroup.allCases {
            let root = Entity()
            root.name = "muscle.\(muscle.rawValue)"

            let models = (groupedBlueprints[muscle] ?? []).map(makeModelEntity(for:))
            for model in models {
                root.addChild(model)
            }

            root.generateCollisionShapes(recursive: true)
            bodyRoot.addChild(root)
            muscleRoots[muscle] = root
            muscleModels[muscle] = models
        }
    }

    private func makeModelEntity(for blueprint: MuscleMap3DPartBlueprint) -> ModelEntity {
        let mesh: MeshResource
        switch blueprint.primitive {
        case .box(let size):
            mesh = .generateBox(size: size)
        case .sphere(let radius):
            mesh = .generateSphere(radius: radius)
        case .cylinder(let height, let radius):
            mesh = .generateCylinder(height: height, radius: radius)
        }

        let entity = ModelEntity(mesh: mesh, materials: [])
        entity.name = blueprint.id
        entity.position = blueprint.position
        entity.orientation = quaternion(fromDegrees: blueprint.rotationDegrees)
        entity.generateCollisionShapes(recursive: false)
        return entity
    }

    private func updateShellMaterials(colorScheme: ColorScheme) {
        let tint: UIColor = colorScheme == .dark
            ? UIColor.white.withAlphaComponent(0.07)
            : UIColor.black.withAlphaComponent(0.08)
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
            base = UIColor(DS.Color.textTertiary).withAlphaComponent(0.3)
        case .recovery(let fatigueLevel):
            base = UIColor(fatigueLevel.color(for: colorScheme))
        case .volume(let intensity):
            base = UIColor(intensity.color)
        }

        guard isSelected else { return base }
        return blended(base, with: .white, ratio: 0.22)
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

private extension MuscleMap3DScene {
    static func buildBlueprints() -> [MuscleMap3DPartBlueprint] {
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

    static var chestParts: [MuscleMap3DPartBlueprint] {
        mirroredBoxes(prefix: "chest", muscle: .chest, x: 0.13, y: 0.36, z: 0.18, size: [0.19, 0.16, 0.08])
    }

    static var shoulderParts: [MuscleMap3DPartBlueprint] {
        mirroredSpheres(prefix: "shoulders", muscle: .shoulders, x: 0.31, y: 0.40, z: 0.02, radius: 0.10)
    }

    static var bicepsParts: [MuscleMap3DPartBlueprint] {
        mirroredCapsules(prefix: "biceps", muscle: .biceps, x: 0.36, y: 0.18, z: 0.13, height: 0.24, radius: 0.055, rotationDegrees: [0, 0, 12])
    }

    static var tricepsParts: [MuscleMap3DPartBlueprint] {
        mirroredCapsules(prefix: "triceps", muscle: .triceps, x: 0.37, y: 0.16, z: -0.12, height: 0.26, radius: 0.055, rotationDegrees: [0, 0, 8])
    }

    static var forearmParts: [MuscleMap3DPartBlueprint] {
        mirroredCapsules(prefix: "forearms", muscle: .forearms, x: 0.41, y: -0.14, z: 0.04, height: 0.26, radius: 0.044, rotationDegrees: [0, 0, 6])
    }

    static var coreParts: [MuscleMap3DPartBlueprint] {
        [
            MuscleMap3DPartBlueprint(
                id: "core-center",
                muscle: .core,
                primitive: .box(size: [0.24, 0.28, 0.08]),
                position: [0, 0.06, 0.17],
                rotationDegrees: .zero
            )
        ]
    }

    static var backParts: [MuscleMap3DPartBlueprint] {
        [
            MuscleMap3DPartBlueprint(
                id: "back-center",
                muscle: .back,
                primitive: .box(size: [0.28, 0.30, 0.09]),
                position: [0, 0.07, -0.17],
                rotationDegrees: .zero
            )
        ]
    }

    static var latsParts: [MuscleMap3DPartBlueprint] {
        mirroredBoxes(prefix: "lats", muscle: .lats, x: 0.18, y: 0.10, z: -0.17, size: [0.10, 0.24, 0.08])
    }

    static var trapsParts: [MuscleMap3DPartBlueprint] {
        [
            MuscleMap3DPartBlueprint(
                id: "traps-center",
                muscle: .traps,
                primitive: .box(size: [0.22, 0.10, 0.07]),
                position: [0, 0.49, -0.08],
                rotationDegrees: .zero
            )
        ]
    }

    static var gluteParts: [MuscleMap3DPartBlueprint] {
        mirroredBoxes(prefix: "glutes", muscle: .glutes, x: 0.12, y: -0.18, z: -0.12, size: [0.15, 0.14, 0.08])
    }

    static var quadricepsParts: [MuscleMap3DPartBlueprint] {
        mirroredCapsules(prefix: "quadriceps", muscle: .quadriceps, x: 0.13, y: -0.54, z: 0.12, height: 0.44, radius: 0.075, rotationDegrees: .zero)
    }

    static var hamstringParts: [MuscleMap3DPartBlueprint] {
        mirroredCapsules(prefix: "hamstrings", muscle: .hamstrings, x: 0.13, y: -0.56, z: -0.11, height: 0.44, radius: 0.075, rotationDegrees: .zero)
    }

    static var calfParts: [MuscleMap3DPartBlueprint] {
        mirroredCapsules(prefix: "calves", muscle: .calves, x: 0.13, y: -1.01, z: -0.05, height: 0.32, radius: 0.055, rotationDegrees: .zero)
    }

    static func mirroredBoxes(
        prefix: String,
        muscle: MuscleGroup,
        x: Float,
        y: Float,
        z: Float,
        size: SIMD3<Float>
    ) -> [MuscleMap3DPartBlueprint] {
        [
            MuscleMap3DPartBlueprint(
                id: "\(prefix)-left",
                muscle: muscle,
                primitive: .box(size: size),
                position: [-x, y, z],
                rotationDegrees: .zero
            ),
            MuscleMap3DPartBlueprint(
                id: "\(prefix)-right",
                muscle: muscle,
                primitive: .box(size: size),
                position: [x, y, z],
                rotationDegrees: .zero
            ),
        ]
    }

    static func mirroredSpheres(
        prefix: String,
        muscle: MuscleGroup,
        x: Float,
        y: Float,
        z: Float,
        radius: Float
    ) -> [MuscleMap3DPartBlueprint] {
        [
            MuscleMap3DPartBlueprint(
                id: "\(prefix)-left",
                muscle: muscle,
                primitive: .sphere(radius: radius),
                position: [-x, y, z],
                rotationDegrees: .zero
            ),
            MuscleMap3DPartBlueprint(
                id: "\(prefix)-right",
                muscle: muscle,
                primitive: .sphere(radius: radius),
                position: [x, y, z],
                rotationDegrees: .zero
            ),
        ]
    }

    static func mirroredCapsules(
        prefix: String,
        muscle: MuscleGroup,
        x: Float,
        y: Float,
        z: Float,
        height: Float,
        radius: Float,
        rotationDegrees: SIMD3<Float>
    ) -> [MuscleMap3DPartBlueprint] {
        [
            MuscleMap3DPartBlueprint(
                id: "\(prefix)-left",
                muscle: muscle,
                primitive: .cylinder(height: height, radius: radius),
                position: [-x, y, z],
                rotationDegrees: rotationDegrees
            ),
            MuscleMap3DPartBlueprint(
                id: "\(prefix)-right",
                muscle: muscle,
                primitive: .cylinder(height: height, radius: radius),
                position: [x, y, z],
                rotationDegrees: [rotationDegrees.x, rotationDegrees.y, -rotationDegrees.z]
            ),
        ]
    }
}

struct MuscleMap3DViewer: UIViewRepresentable {
    let fatigueStates: [MuscleFatigueState]
    let mode: MuscleMap3DMode
    let colorScheme: ColorScheme
    @Binding var selectedMuscle: MuscleGroup?
    let resetToken: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedMuscle: $selectedMuscle)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.backgroundColor = .clear
        context.coordinator.attach(to: view)
        context.coordinator.update(
            fatigueStates: fatigueStates,
            mode: mode,
            colorScheme: colorScheme,
            selectedMuscle: selectedMuscle,
            resetToken: resetToken
        )
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.update(
            fatigueStates: fatigueStates,
            mode: mode,
            colorScheme: colorScheme,
            selectedMuscle: selectedMuscle,
            resetToken: resetToken
        )
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let scene = MuscleMap3DScene()
        private var selectedMuscle: Binding<MuscleGroup?>
        private weak var view: ARView?
        private var yaw: Float = MuscleMap3DState.defaultYaw
        private var pitch: Float = MuscleMap3DState.defaultPitch
        private var zoomScale: Float = 1.0
        private var panStartYaw: Float = 0
        private var panStartPitch: Float = 0
        private var pinchStartScale: Float = 1.0
        private var appliedResetToken = -1
        private var lastSelectedMuscle: MuscleGroup?

        init(selectedMuscle: Binding<MuscleGroup?>) {
            self.selectedMuscle = selectedMuscle
        }

        func attach(to view: ARView) {
            self.view = view
            scene.installIfNeeded(in: view)
            installGestures(on: view)
            scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: zoomScale)
        }

        func update(
            fatigueStates: [MuscleFatigueState],
            mode: MuscleMap3DMode,
            colorScheme: ColorScheme,
            selectedMuscle: MuscleGroup?,
            resetToken: Int
        ) {
            if appliedResetToken != resetToken {
                appliedResetToken = resetToken
                resetTransform()
            }

            if selectedMuscle != lastSelectedMuscle {
                lastSelectedMuscle = selectedMuscle
                focus(on: selectedMuscle)
            }

            scene.updateVisuals(
                fatigueStates: fatigueStates,
                mode: mode,
                selectedMuscle: selectedMuscle,
                colorScheme: colorScheme
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer) ||
            (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer)
        }

        private func installGestures(on view: ARView) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            tap.require(toFail: doubleTap)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self

            view.addGestureRecognizer(tap)
            view.addGestureRecognizer(doubleTap)
            view.addGestureRecognizer(pan)
            view.addGestureRecognizer(pinch)
        }

        private func resetTransform() {
            yaw = MuscleMap3DState.defaultYaw
            pitch = MuscleMap3DState.defaultPitch
            zoomScale = 1.0
            scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: zoomScale)
        }

        private func focus(on muscle: MuscleGroup?) {
            guard let muscle else { return }
            yaw = MuscleMap3DState.preferredYaw(for: muscle)
            pitch = MuscleMap3DState.defaultPitch
            scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: zoomScale)
        }

        @objc
        private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view else { return }
            let location = recognizer.location(in: view)
            guard let entity = view.entities(at: location).first,
                  let muscle = scene.muscle(for: entity) else { return }
            selectedMuscle.wrappedValue = muscle
        }

        @objc
        private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            resetTransform()
        }

        @objc
        private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                panStartYaw = yaw
                panStartPitch = pitch
            case .changed:
                let translation = recognizer.translation(in: recognizer.view)
                yaw = panStartYaw + (Float(translation.x) * MuscleMap3DState.rotationSensitivity)
                pitch = MuscleMap3DState.clampedPitch(
                    panStartPitch + (Float(translation.y) * MuscleMap3DState.pitchSensitivity)
                )
                scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: zoomScale)
            default:
                break
            }
        }

        @objc
        private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                pinchStartScale = zoomScale
            case .changed:
                zoomScale = MuscleMap3DState.clampedZoomScale(
                    pinchStartScale * Float(recognizer.scale)
                )
                scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: zoomScale)
            default:
                break
            }
        }
    }
}
