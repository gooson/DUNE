import SwiftUI

struct VisionVolumetricExperienceView: View {
    @State private var viewModel: VisionSpatialViewModel

    init(sharedHealthDataService: SharedHealthDataService? = nil) {
        _viewModel = State(initialValue: VisionSpatialViewModel(sharedHealthDataService: sharedHealthDataService))
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                loadingState
            case .unavailable(let message):
                messageState(message)
            case .failed(let message):
                messageState(message)
            case .ready:
                readyContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricRoot)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            scenePickerOrnament
        }
        .ornament(attachmentAnchor: .scene(.trailing)) {
            trailingOrnament
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .simulatorAdvancedMockDataDidChange)) { _ in
            Task { @MainActor in
                await viewModel.reload()
            }
        }
    }

    // MARK: - Ornaments

    private var scenePickerOrnament: some View {
        VStack(spacing: 12) {
            Picker("Scene", selection: $viewModel.selectedScene) {
                ForEach(VisionSpatialSceneKind.allCases) { scene in
                    Text(scene.title).tag(scene)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)
            .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricScenePicker)

            Text(viewModel.selectedScene.description)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassBackgroundEffect()
        .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricScenePickerOrnament)
    }

    @ViewBuilder
    private var trailingOrnament: some View {
        if viewModel.loadState == .ready, let summary = viewModel.summary {
            VStack(alignment: .leading, spacing: 14) {
                metricStrip(summary)

                if viewModel.selectedScene != .heartRateOrb, !summary.featuredMuscles.isEmpty {
                    muscleStrip(summary.featuredMuscles)
                }
            }
            .padding(16)
            .frame(maxWidth: 340)
            .glassBackgroundEffect()
            .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricTrailingOrnament)
        }
    }

    // MARK: - Main Content

    private var readyContent: some View {
        Group {
            if let summary = viewModel.summary {
                VStack(alignment: .leading, spacing: 18) {
                    sceneStage(summary)

                    if let message = viewModel.message {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                messageState(String(localized: "Spatial data could not be loaded."))
            }
        }
    }

    private func sceneStage(_ summary: SpatialTrainingSummary) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)

            sceneView(summary)
                .padding(12)

            VStack(alignment: .leading, spacing: 6) {
                Text(sceneTitle)
                    .font(.headline)
                Text(sceneSubtitle(summary))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricSceneStage)
    }

    @ViewBuilder
    private func sceneView(_ summary: SpatialTrainingSummary) -> some View {
        switch viewModel.selectedScene {
        case .heartRateOrb:
            HeartRateOrbSceneView(orb: summary.heartRateOrb)
                .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricSceneID(for: .heartRateOrb))
        case .trainingBlocks:
            TrainingVolumeBlocksSceneView(
                muscles: summary.featuredMuscles.isEmpty ? Array(summary.muscleLoads.prefix(6)) : summary.featuredMuscles,
                selectedMuscle: viewModel.selectedMuscle
            )
            .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricSceneID(for: .trainingBlocks))
        case .bodyHeatmap:
            BodyHeatmapSceneView(
                muscleLoads: summary.muscleLoads,
                selectedMuscle: viewModel.selectedMuscle
            )
            .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricSceneID(for: .bodyHeatmap))
        }
    }

    // MARK: - Metric & Muscle Strips (in ornament)

    private func metricStrip(_ summary: SpatialTrainingSummary) -> some View {
        let selected = selectedMuscleLoad(in: summary)

        return VStack(alignment: .leading, spacing: 10) {
            metricCard(
                title: Text("Live BPM"),
                value: summary.heartRateOrb.displayBPM.map(String.init) ?? "--",
                detail: summary.heartRateOrb.isLive ? Text("Latest heart rate") : Text("Baseline fallback"),
                icon: "heart.fill"
            )

            metricCard(
                title: Text("Baseline RHR"),
                value: summary.heartRateOrb.baselineRHR.map { Int($0.rounded()).formatted() } ?? "--",
                detail: summary.heartRateOrb.deltaFromBaseline
                    .map { Text(deltaFromBaselineDetail($0)) }
                    ?? Text("No delta available"),
                icon: "waveform.path.ecg"
            )

            metricCard(
                title: Text(verbatim: selected?.muscle.displayName ?? String(localized: "Focus Muscle")),
                value: selected?.loadLabel ?? "--",
                detail: Text(verbatim: selected?.fatigueLabel ?? String(localized: "No load detected")),
                icon: selected?.muscle.iconName ?? "figure.strengthtraining.traditional"
            )
        }
        .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricMetricStrip)
    }

    private func metricCard(
        title: Text,
        value: String,
        detail: Text,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.tint)

            Text(value)
                .font(.title3.weight(.semibold))

            title
                .font(.callout.weight(.medium))

            detail
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func muscleStrip(_ muscles: [SpatialTrainingSummary.MuscleLoad]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(muscles) { muscleLoad in
                    Button {
                        viewModel.selectMuscle(muscleLoad.muscle)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: muscleLoad.muscle.iconName)
                                .font(.callout)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(muscleLoad.muscle.displayName)
                                    .font(.callout.weight(.semibold))
                                Text(muscleLoad.loadLabel)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            muscleCardBackground(for: muscleLoad),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 240)
        .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricMuscleStrip)
    }

    private func muscleCardBackground(for muscleLoad: SpatialTrainingSummary.MuscleLoad) -> some ShapeStyle {
        let isSelected = viewModel.selectedMuscle == muscleLoad.muscle
        return isSelected ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial)
    }

    // MARK: - State Views

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading spatial health data")
                .font(.headline)
            Text("Fetching recent workouts, baseline heart rate, and live pulse.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricLoadingState)
    }

    private func messageState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button {
                Task {
                    await viewModel.reload()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricRetryButton)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .accessibilityIdentifier(VisionSurfaceAccessibility.volumetricMessageState)
    }

    // MARK: - Helpers

    private var sceneTitle: String {
        switch viewModel.selectedScene {
        case .heartRateOrb:
            String(localized: "Heart Rate Orb")
        case .trainingBlocks:
            String(localized: "Training Volume Blocks")
        case .bodyHeatmap:
            String(localized: "Body Heatmap")
        }
    }

    private func sceneSubtitle(_ summary: SpatialTrainingSummary) -> String {
        switch viewModel.selectedScene {
        case .heartRateOrb:
            if let date = viewModel.latestHeartRateDate {
                return String(localized: "Latest sample: \(date.formatted(date: .abbreviated, time: .shortened))")
            }
            return String(localized: "Using baseline RHR when live heart rate is unavailable.")
        case .trainingBlocks:
            return String(localized: "Load units are estimated from HealthKit workout duration and distance.")
        case .bodyHeatmap:
            return String(localized: "Drag to rotate. Highlighted muscles reflect recent recovery strain.")
        }
    }

    private func selectedMuscleLoad(in summary: SpatialTrainingSummary) -> SpatialTrainingSummary.MuscleLoad? {
        if let selectedMuscle {
            return summary.muscleLoads.first { $0.muscle == selectedMuscle }
        }
        return summary.featuredMuscles.first
    }

    private func deltaFromBaselineDetail(_ delta: Int) -> String {
        let signedDelta = delta > 0 ? "+\(delta)" : "\(delta)"
        return String(localized: "\(signedDelta) bpm from baseline")
    }

    private var selectedMuscle: MuscleGroup? {
        viewModel.selectedMuscle
    }
}
