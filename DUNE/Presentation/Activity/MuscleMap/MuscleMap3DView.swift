import SwiftUI
import RealityKit

/// Actual 3D muscle map built from SVG-derived volumetric meshes.
struct MuscleMap3DView: View {
    let fatigueStates: [MuscleFatigueState]
    let highlightedMuscle: MuscleGroup?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var mode: MuscleMap3DMode = .recovery
    @State private var selectedMuscle: MuscleGroup?
    @AppStorage("muscleMap3D.anatomyLayer") private var anatomyLayerRawValue = MuscleMap3DAnatomyLayer.skin.rawValue
    @AppStorage("muscleMap3D.shellOpacity") private var shellOpacity: Double = Double(MuscleMap3DState.defaultShellOpacity)
    @State private var resetToken = 0

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

    private var viewerHeight: CGFloat {
        sizeClass == .regular ? 560 : 430
    }

    private var anatomyLayer: MuscleMap3DAnatomyLayer {
        MuscleMap3DAnatomyLayer(rawValue: anatomyLayerRawValue) ?? .skin
    }

    private var anatomyLayerSelection: Binding<MuscleMap3DAnatomyLayer> {
        Binding(
            get: { anatomyLayer },
            set: { anatomyLayerRawValue = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                summaryCard
                    .accessibilityIdentifier("musclemap-3d-summary-card")

                Picker("Mode", selection: $mode) {
                    ForEach(MuscleMap3DMode.allCases, id: \.rawValue) { currentMode in
                        Text(currentMode.label).tag(currentMode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("musclemap-3d-mode-picker")

                layerPicker
                    .accessibilityIdentifier("musclemap-3d-layer-picker")

                if anatomyLayer == .skin {
                    skinOpacitySlider
                        .accessibilityIdentifier("musclemap-3d-skin-slider")
                }

                MuscleMap3DViewer(
                    fatigueStates: fatigueStates,
                    mode: mode,
                    anatomyLayer: anatomyLayer,
                    colorScheme: colorScheme,
                    selectedMuscle: $selectedMuscle,
                    shellOpacity: Float(shellOpacity),
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
                .accessibilityIdentifier("musclemap-3d-viewer")

                muscleSelectionStrip
                    .accessibilityIdentifier("musclemap-3d-muscle-strip")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .accessibilityIdentifier("activity-musclemap-3d-screen")
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
            String(localized: "No Data")
        case .recovery(let fatigueLevel):
            fatigueLevel.displayName
        case .volume(let intensity):
            intensity.description
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

    private var layerPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Layer")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

            Picker("Layer", selection: anatomyLayerSelection) {
                ForEach(MuscleMap3DAnatomyLayer.allCases, id: \.rawValue) { currentLayer in
                    Text(currentLayer.label).tag(currentLayer)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var skinOpacitySlider: some View {
        HStack(spacing: DS.Spacing.sm) {
            Label("Skin", systemImage: "eye")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: true, vertical: false)
            Slider(value: $shellOpacity, in: 0...0.5) {
                Text("Skin Opacity")
            } minimumValueLabel: {
                Image(systemName: "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            } maximumValueLabel: {
                Image(systemName: "eye")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .tint(DS.Color.activity)
        }
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
