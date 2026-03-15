import SwiftUI
import RealityKit

/// Immersive 3D muscle map with fullscreen viewer and overlay controls.
struct MuscleMap3DView: View {
    let fatigueStates: [MuscleFatigueState]
    let highlightedMuscle: MuscleGroup?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var mode: MuscleMap3DMode = .recovery
    @State private var selectedMuscle: MuscleGroup?
    @AppStorage("muscleMap3D.anatomyLayer") private var anatomyLayerRawValue = MuscleMap3DAnatomyLayer.muscles.rawValue
    @AppStorage("muscleMap3D.shellOpacity") private var shellOpacity: Double = Double(MuscleMap3DState.defaultShellOpacity)
    @State private var resetToken = 0
    @State private var showControls = true

    init(fatigueStates: [MuscleFatigueState], highlightedMuscle: MuscleGroup?) {
        self.fatigueStates = fatigueStates
        self.highlightedMuscle = highlightedMuscle
        _selectedMuscle = State(
            initialValue: MuscleMap3DState.defaultSelectedMuscle(
                highlighted: highlightedMuscle,
                fatigueStates: fatigueStates
            )
        )
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

    private var anatomyLayer: MuscleMap3DAnatomyLayer {
        MuscleMap3DAnatomyLayer(rawValue: anatomyLayerRawValue) ?? .muscles
    }

    private var anatomyLayerSelection: Binding<MuscleMap3DAnatomyLayer> {
        Binding(
            get: { anatomyLayer },
            set: { anatomyLayerRawValue = $0.rawValue }
        )
    }

    var body: some View {
        ZStack {
            // Full-screen 3D viewer
            MuscleMap3DViewer(
                fatigueStates: fatigueStates,
                mode: mode,
                anatomyLayer: anatomyLayer,
                colorScheme: colorScheme,
                selectedMuscle: $selectedMuscle,
                shellOpacity: Float(shellOpacity),
                resetToken: resetToken
            )
            .ignoresSafeArea()
            .accessibilityIdentifier("musclemap-3d-viewer")

            // Overlay controls
            if showControls {
                overlayControls
                    .transition(.opacity)
            }
        }
        .background(Color.black)
        .accessibilityIdentifier("activity-musclemap-3d-screen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(DS.Animation.snappy) {
                        resetToken += 1
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(DS.Spacing.xs)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityIdentifier("musclemap-3d-reset-button")
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

    // MARK: - Overlay Controls

    private var overlayControls: some View {
        VStack {
            Spacer()

            VStack(spacing: DS.Spacing.md) {
                // Info card at bottom
                summaryStrip
                    .accessibilityIdentifier("musclemap-3d-summary-card")

                // Mode + Layer controls
                HStack(spacing: DS.Spacing.sm) {
                    compactModePicker
                        .accessibilityIdentifier("musclemap-3d-mode-picker")
                    compactLayerPicker
                        .accessibilityIdentifier("musclemap-3d-layer-picker")
                }

                // Muscle selection strip
                muscleSelectionStrip
                    .accessibilityIdentifier("musclemap-3d-muscle-strip")
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: selectedMuscle?.iconName ?? "figure.strengthtraining.traditional")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedMuscle?.displayName ?? String(localized: "No Data"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(summaryValue(for: selectedState))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(primaryMetricValue)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(mode == .recovery ? String(localized: "Recovery") : String(localized: "Volume"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private var compactModePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(MuscleMap3DMode.allCases, id: \.rawValue) { currentMode in
                Text(currentMode.label).tag(currentMode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var compactLayerPicker: some View {
        Picker("Layer", selection: anatomyLayerSelection) {
            ForEach(MuscleMap3DAnatomyLayer.allCases, id: \.rawValue) { currentLayer in
                Text(currentLayer.label).tag(currentLayer)
            }
        }
        .pickerStyle(.segmented)
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

    private var muscleSelectionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
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
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .foregroundStyle(selectedMuscle == muscle ? .white : .white.opacity(0.7))
                        .background(
                            selectedMuscle == muscle
                                ? DS.Color.activity.opacity(0.4)
                                : Color.white.opacity(0.1),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }
}

struct MuscleMap3DViewer: View {
    let fatigueStates: [MuscleFatigueState]
    let mode: MuscleMap3DMode
    let anatomyLayer: MuscleMap3DAnatomyLayer
    let colorScheme: ColorScheme
    @Binding var selectedMuscle: MuscleGroup?
    let shellOpacity: Float
    let resetToken: Int

    @MainActor
    private var bodyScene: some View {
        RealityView { content in
            if scene.anchor.parent == nil {
                content.add(scene.anchor)
            }

            await scene.prepareIfNeeded()
            hasLoadedScene = true
            refreshScene()
        } update: { _ in
            refreshScene()
        }
        .accessibilityIdentifier("musclemap-3d-viewer")
        .onTapGesture(count: 2) {
            resetTransform()
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    selectedMuscle = scene.muscle(for: value.entity)
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    yaw = panStartYaw + (Float(value.translation.width) * MuscleMap3DState.rotationSensitivity)
                    pitch = MuscleMap3DState.clampedPitch(
                        panStartPitch + (Float(value.translation.height) * MuscleMap3DState.pitchSensitivity)
                    )
                    refreshScene()
                }
                .onEnded { _ in
                    panStartYaw = yaw
                    panStartPitch = pitch
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    zoomScale = MuscleMap3DState.clampedZoomScale(
                        pinchStartScale * Float(value.magnification)
                    )
                    refreshScene()
                }
                .onEnded { _ in
                    pinchStartScale = zoomScale
                }
        )
    }

    @State private var scene = MuscleMap3DScene()
    @State private var yaw: Float = MuscleMap3DState.defaultYaw
    @State private var pitch: Float = MuscleMap3DState.defaultPitch
    @State private var zoomScale: Float = 1.0
    @State private var panStartYaw: Float = MuscleMap3DState.defaultYaw
    @State private var panStartPitch: Float = MuscleMap3DState.defaultPitch
    @State private var pinchStartScale: Float = 1.0
    @State private var appliedResetToken = -1
    @State private var hasLoadedScene = false

    var body: some View {
        bodyScene
            .overlay {
                if !hasLoadedScene {
                    ProgressView()
                        .controlSize(.regular)
                }
            }
            .task {
                if let selectedMuscle {
                    focus(on: selectedMuscle)
                } else {
                    refreshScene()
                }
            }
            .onChange(of: selectedMuscle) { _, newValue in
                if let newValue {
                    focus(on: newValue)
                } else {
                    refreshScene()
                }
            }
            .onChange(of: mode) { _, _ in
                refreshScene()
            }
            .onChange(of: anatomyLayer) { _, _ in
                refreshScene()
            }
            .onChange(of: colorScheme) { _, _ in
                refreshScene()
            }
            .task(id: resetToken) {
                guard appliedResetToken != resetToken else { return }
                appliedResetToken = resetToken
                resetTransform()
            }
    }

    @MainActor
    private func refreshScene() {
        scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: zoomScale)
        scene.updateVisuals(
            fatigueStates: fatigueStates,
            mode: mode,
            selectedMuscle: selectedMuscle,
            anatomyLayer: anatomyLayer,
            colorScheme: colorScheme,
            shellOpacity: shellOpacity
        )
    }

    @MainActor
    private func resetTransform() {
        yaw = MuscleMap3DState.defaultYaw
        pitch = MuscleMap3DState.defaultPitch
        zoomScale = 1.0
        panStartYaw = yaw
        panStartPitch = pitch
        pinchStartScale = zoomScale
        refreshScene()
    }

    @MainActor
    private func focus(on muscle: MuscleGroup) {
        yaw = MuscleMap3DState.preferredYaw(for: muscle)
        pitch = MuscleMap3DState.defaultPitch
        panStartYaw = yaw
        panStartPitch = pitch
        refreshScene()
    }
}
