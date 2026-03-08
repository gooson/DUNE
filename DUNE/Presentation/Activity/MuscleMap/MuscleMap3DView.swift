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
                    .accessibilityIdentifier("musclemap-3d-summary-card")

                Picker("Mode", selection: $mode) {
                    ForEach(MuscleMap3DMode.allCases, id: \.rawValue) { currentMode in
                        Text(currentMode.label).tag(currentMode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("musclemap-3d-mode-picker")

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
        private var latestFatigueStates: [MuscleFatigueState] = []
        private var latestMode: MuscleMap3DMode = .recovery
        private var latestColorScheme: ColorScheme = .dark
        private var isSceneReady = false

        init(selectedMuscle: Binding<MuscleGroup?>) {
            self.selectedMuscle = selectedMuscle
        }

        func attach(to view: ARView) {
            self.view = view
            scene.installIfNeeded(in: view)
            installGestures(on: view)
            scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: zoomScale)

            Task { @MainActor [weak self] in
                guard let self else { return }
                await scene.prepareIfNeeded()
                isSceneReady = true
                refreshScene()
            }
        }

        func update(
            fatigueStates: [MuscleFatigueState],
            mode: MuscleMap3DMode,
            colorScheme: ColorScheme,
            selectedMuscle: MuscleGroup?,
            resetToken: Int
        ) {
            latestFatigueStates = fatigueStates
            latestMode = mode
            latestColorScheme = colorScheme

            if appliedResetToken != resetToken {
                appliedResetToken = resetToken
                resetTransform()
            }

            if selectedMuscle != lastSelectedMuscle {
                lastSelectedMuscle = selectedMuscle
                focus(on: selectedMuscle)
            }

            refreshScene()
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

        private func refreshScene() {
            scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: zoomScale)
            guard isSceneReady else { return }
            scene.updateVisuals(
                fatigueStates: latestFatigueStates,
                mode: latestMode,
                selectedMuscle: selectedMuscle.wrappedValue,
                colorScheme: latestColorScheme
            )
        }

        private func resetTransform() {
            yaw = MuscleMap3DState.defaultYaw
            pitch = MuscleMap3DState.defaultPitch
            zoomScale = 1.0
            refreshScene()
        }

        private func focus(on muscle: MuscleGroup?) {
            guard let muscle else { return }
            yaw = MuscleMap3DState.preferredYaw(for: muscle)
            pitch = MuscleMap3DState.defaultPitch
            refreshScene()
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
                refreshScene()
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
                refreshScene()
            default:
                break
            }
        }
    }
}
