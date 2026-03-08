import SwiftUI

struct VisionTrainView: View {
    @State var viewModel: VisionTrainViewModel
    private let onOpen3DCharts: () -> Void

    init(
        viewModel: VisionTrainViewModel,
        onOpen3DCharts: @escaping () -> Void = {}
    ) {
        self._viewModel = State(wrappedValue: viewModel)
        self.onOpen3DCharts = onOpen3DCharts
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroCard

                switch viewModel.loadState {
                case .idle, .loading:
                    loadingView
                case .ready:
                    VisionSharePlayWorkoutCard()
                        .accessibilityIdentifier(VisionSurfaceAccessibility.trainSharePlayCard)
                    VisionVoiceWorkoutEntryCard()
                        .accessibilityIdentifier(VisionSurfaceAccessibility.trainVoiceEntryCard)
                    VisionExerciseFormGuideView()
                        .accessibilityIdentifier(VisionSurfaceAccessibility.trainExerciseGuideCard)
                    VisionMuscleMapExperienceView(
                        fatigueStates: viewModel.fatigueStates,
                        initialMuscle: .back
                    )
                    .accessibilityIdentifier(VisionSurfaceAccessibility.trainMuscleMapCard)
                case .unavailable(let message):
                    emptyStateView(message: message)
                case .failed(let message):
                    errorView(message: message)
                }
            }
            .padding(24)
        }
        .accessibilityIdentifier(VisionSurfaceAccessibility.trainRoot)
        .navigationTitle("Activity")
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spatial Strength View")
                .font(.largeTitle.weight(.bold))

            Text("View your muscle fatigue and recovery status in spatial 3D. Data is synced from your workouts on iPhone and Apple Watch.")
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                onOpen3DCharts()
            } label: {
                Label("Open 3D Charts", systemImage: "chart.bar.fill")
            }
            .accessibilityIdentifier(VisionSurfaceAccessibility.trainOpenChart3DButton)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityIdentifier(VisionSurfaceAccessibility.trainHeroCard)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading training data...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityIdentifier(VisionSurfaceAccessibility.trainLoadingState)
    }

    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Training Data")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityIdentifier(VisionSurfaceAccessibility.trainUnavailableState)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button {
                Task { await viewModel.reload() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityIdentifier(VisionSurfaceAccessibility.trainFailedState)
    }
}
