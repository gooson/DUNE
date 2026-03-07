import SwiftUI
import RealityKit

struct VisionMuscleMapExperienceView: View {
    let fatigueStates: [MuscleFatigueState]
    let initialMuscle: MuscleGroup?

    @Environment(\.colorScheme) private var colorScheme
    @State private var mode: MuscleMap3DMode = .recovery
    @State private var selectedMuscle: MuscleGroup?
    @State private var yaw: Float = MuscleMap3DState.defaultYaw
    @State private var pitch: Float = MuscleMap3DState.defaultPitch
    @State private var zoomScale: Float = 1.0
    @State private var dragStartYaw: Float = MuscleMap3DState.defaultYaw
    @State private var dragStartPitch: Float = MuscleMap3DState.defaultPitch
    @State private var pinchStartScale: Float = 1.0
    @State private var hasLoadedScene = false
    @State private var scene = MuscleMap3DScene()

    @State private var fatigueByMuscle: [MuscleGroup: MuscleFatigueState] = [:]

    init(
        fatigueStates: [MuscleFatigueState],
        initialMuscle: MuscleGroup? = nil
    ) {
        self.fatigueStates = fatigueStates
        self.initialMuscle = initialMuscle
        _selectedMuscle = State(initialValue: initialMuscle)
        _fatigueByMuscle = State(
            initialValue: Dictionary(fatigueStates.map { ($0.muscle, $0) }, uniquingKeysWith: { _, latest in latest })
        )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            summaryCard

            Picker("Mode", selection: $mode) {
                ForEach(MuscleMap3DMode.allCases, id: \.rawValue) { currentMode in
                    Text(currentMode.label).tag(currentMode)
                }
            }
            .pickerStyle(.segmented)

            RealityView { content in
                if scene.anchor.parent == nil {
                    content.add(scene.anchor)
                }
                await scene.prepareIfNeeded()
                applySceneState()
                hasLoadedScene = true
            } update: { _ in
                applySceneState()
            }
            .frame(minHeight: 460)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    resetTransform()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .labelStyle(.titleAndIcon)
                .padding(18)
            }
            .overlay {
                if !hasLoadedScene {
                    ProgressView("Generating 3D body mesh…")
                        .padding(20)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            .gesture(
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        selectedMuscle = scene.muscle(for: value.entity)
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        yaw = dragStartYaw + (Float(value.translation.width) * MuscleMap3DState.rotationSensitivity)
                        pitch = MuscleMap3DState.clampedPitch(
                            dragStartPitch + (Float(value.translation.height) * MuscleMap3DState.pitchSensitivity)
                        )
                        applySceneState()
                    }
                    .onEnded { _ in
                        dragStartYaw = yaw
                        dragStartPitch = pitch
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        zoomScale = MuscleMap3DState.clampedZoomScale(
                            pinchStartScale * Float(value.magnification)
                        )
                        applySceneState()
                    }
                    .onEnded { _ in
                        pinchStartScale = zoomScale
                    }
            )
            .onTapGesture(count: 2) {
                resetTransform()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        Button {
                            selectedMuscle = muscle
                            focus(on: muscle)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: muscle.iconName)
                                    .font(.callout)
                                Text(muscle.displayName)
                                    .font(.callout.weight(.medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                selectedMuscle == muscle
                                    ? AnyShapeStyle(.tint.opacity(0.22))
                                    : AnyShapeStyle(.thinMaterial),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task {
            if selectedMuscle == nil {
                let resolved = MuscleMap3DState.defaultSelectedMuscle(
                    highlighted: initialMuscle,
                    fatigueStates: fatigueStates
                )
                selectedMuscle = resolved
                focus(on: resolved)
            }
        }
        .onChange(of: selectedMuscle) { _, newValue in
            if let newValue {
                focus(on: newValue)
            }
        }
        .onChange(of: mode) { _, _ in
            applySceneState()
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spatial Muscle Map")
                .font(.title2.weight(.semibold))

            Text(summaryValue(for: selectedState))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                metricValue(
                    title: primaryMetricTitle,
                    value: primaryMetricValue
                )
                metricValue(
                    title: secondaryMetricTitle,
                    value: secondaryMetricValue
                )
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func metricValue(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryMetricTitle: LocalizedStringKey {
        mode == .recovery ? "Recovery" : "Weekly Volume"
    }

    private var secondaryMetricTitle: LocalizedStringKey {
        mode == .recovery ? "Weekly Volume" : "Recovery"
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
        guard let selectedFatigueState else { return String(localized: "No Data") }

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
            String(localized: "No Data")
        case .recovery(let fatigueLevel):
            fatigueLevel.displayName
        case .volume(let intensity):
            intensity.description
        }
    }

    private func applySceneState() {
        scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: zoomScale)
        scene.updateVisuals(
            fatigueStates: fatigueStates,
            mode: mode,
            selectedMuscle: selectedMuscle,
            colorScheme: colorScheme
        )
    }

    private func resetTransform() {
        yaw = MuscleMap3DState.defaultYaw
        pitch = MuscleMap3DState.defaultPitch
        zoomScale = 1.0
        dragStartYaw = yaw
        dragStartPitch = pitch
        pinchStartScale = zoomScale
        applySceneState()
    }

    private func focus(on muscle: MuscleGroup) {
        yaw = MuscleMap3DState.preferredYaw(for: muscle)
        pitch = MuscleMap3DState.defaultPitch
        dragStartYaw = yaw
        dragStartPitch = pitch
        applySceneState()
    }

}
