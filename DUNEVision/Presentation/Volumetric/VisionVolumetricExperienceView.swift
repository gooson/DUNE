import SwiftUI

struct VisionVolumetricExperienceView: View {
    @State private var viewModel: VisionSpatialViewModel

    init(sharedHealthDataService: SharedHealthDataService? = nil) {
        _viewModel = State(initialValue: VisionSpatialViewModel(sharedHealthDataService: sharedHealthDataService))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Picker("Scene", selection: $viewModel.selectedScene) {
                ForEach(VisionSpatialSceneKind.allCases) { scene in
                    Text(scene.title).tag(scene)
                }
            }
            .pickerStyle(.segmented)

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
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spatial Recovery Volume")
                    .font(.title2.weight(.semibold))
                Text(viewModel.selectedScene.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.reload()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var readyContent: some View {
        Group {
            if let summary = viewModel.summary {
                VStack(alignment: .leading, spacing: 18) {
                    sceneStage(summary)
                    metricStrip(summary)

                    if viewModel.selectedScene != .heartRateOrb, !summary.featuredMuscles.isEmpty {
                        muscleStrip(summary.featuredMuscles)
                    }

                    if let message = viewModel.message {
                        Text(message)
                            .font(.footnote)
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
    }

    @ViewBuilder
    private func sceneView(_ summary: SpatialTrainingSummary) -> some View {
        switch viewModel.selectedScene {
        case .heartRateOrb:
            HeartRateOrbSceneView(orb: summary.heartRateOrb)
        case .trainingBlocks:
            TrainingVolumeBlocksSceneView(
                muscles: summary.featuredMuscles.isEmpty ? Array(summary.muscleLoads.prefix(6)) : summary.featuredMuscles,
                selectedMuscle: viewModel.selectedMuscle
            )
        case .bodyHeatmap:
            BodyHeatmapSceneView(
                muscleLoads: summary.muscleLoads,
                selectedMuscle: viewModel.selectedMuscle
            )
        }
    }

    private func metricStrip(_ summary: SpatialTrainingSummary) -> some View {
        let selected = selectedMuscleLoad(in: summary)

        return HStack(spacing: 14) {
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
                title: Text(verbatim: selected?.muscle.spatialDisplayName ?? String(localized: "Focus Muscle")),
                value: selected?.loadLabel ?? "--",
                detail: Text(verbatim: selected?.fatigueLabel ?? String(localized: "No load detected")),
                icon: selected?.muscle.spatialIconName ?? "figure.strengthtraining.traditional"
            )
        }
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
                .font(.subheadline.weight(.medium))

            detail
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func muscleStrip(_ muscles: [SpatialTrainingSummary.MuscleLoad]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(muscles) { muscleLoad in
                    Button {
                        viewModel.selectMuscle(muscleLoad.muscle)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: muscleLoad.muscle.spatialIconName)
                                    .font(.caption)
                                Text(muscleLoad.muscle.spatialDisplayName)
                                    .font(.caption.weight(.semibold))
                            }

                            Text(muscleLoad.loadLabel)
                                .font(.headline)

                            Text(muscleLoad.recoveryLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(
                            background(for: muscleLoad),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func background(for muscleLoad: SpatialTrainingSummary.MuscleLoad) -> some ShapeStyle {
        let isSelected = viewModel.selectedMuscle == muscleLoad.muscle
        return isSelected ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial)
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading spatial health data")
                .font(.headline)
            Text("Fetching recent workouts, baseline heart rate, and live pulse.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
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
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

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

    private var background: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.18),
                Color.blue.opacity(0.14),
                Color.orange.opacity(0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
