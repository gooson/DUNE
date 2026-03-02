import SwiftUI
import SwiftData

/// Full-screen cardio session with real-time timer, distance, pace, and calories.
struct CardioSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CardioSessionViewModel
    @State private var showEndConfirmation = false
    @State private var showSummary = false

    let exercise: ExerciseDefinition
    let onComplete: () -> Void

    init(exercise: ExerciseDefinition, activityType: WorkoutActivityType, isOutdoor: Bool, onComplete: @escaping () -> Void) {
        self.exercise = exercise
        self.onComplete = onComplete
        self._viewModel = State(initialValue: CardioSessionViewModel(
            exercise: exercise,
            activityType: activityType,
            isOutdoor: isOutdoor
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Spacer()
            primaryMetric
            Spacer()
            if viewModel.showsDistance {
                distanceSection
                Spacer()
            }
            secondaryMetrics
            Spacer()
            controlButtons
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
        .background { DetailWaveBackground() }
        .navigationTitle(exercise.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog(
            String(localized: "End Workout?"),
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "End Workout"), role: .destructive) {
                Task {
                    await viewModel.end()
                    showSummary = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save and finish this workout?")
        }
        .navigationDestination(isPresented: $showSummary) {
            CardioSessionSummaryView(
                viewModel: viewModel,
                exercise: exercise,
                onComplete: onComplete
            )
        }
        .task {
            if viewModel.state == .idle {
                viewModel.start()
            }
        }
        .alert(
            "Notice",
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: viewModel.activityType.iconName)
                .font(.subheadline)
                .foregroundStyle(DS.Color.activity)

            Text(viewModel.isOutdoor
                 ? String(localized: "Outdoor")
                 : String(localized: "Indoor"))
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)

            Spacer()

            statusBadge
        }
        .padding(.top, DS.Spacing.md)
    }

    private var statusBadge: some View {
        let (color, label): (SwiftUI.Color, String) = switch viewModel.state {
        case .idle: (DS.Color.textTertiary, String(localized: "Ready"))
        case .running: (DS.Color.positive, String(localized: "Active"))
        case .paused: (DS.Color.caution, String(localized: "Paused"))
        case .finished: (DS.Color.textTertiary, String(localized: "Finished"))
        }

        return HStack(spacing: DS.Spacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Primary: Elapsed Time

    private var primaryMetric: some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(viewModel.formattedElapsed)
                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.default, value: viewModel.formattedElapsed)

            Text("Elapsed Time")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Distance Section

    private var distanceSection: some View {
        HStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.xxs) {
                Text(viewModel.formattedDistance)
                    .font(.system(.title, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(DS.Color.positive)
                    .contentTransition(.numericText())
                    .animation(.default, value: viewModel.formattedDistance)
                Text("km")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            VStack(spacing: DS.Spacing.xxs) {
                Text(viewModel.formattedPace)
                    .font(.system(.title, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(DS.Color.activity)
                    .contentTransition(.numericText())
                    .animation(.default, value: viewModel.formattedPace)
                Text("/km")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    // MARK: - Secondary Metrics

    private var secondaryMetrics: some View {
        HStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.xxs) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(DS.Color.caution)
                Text(viewModel.estimatedCalories > 0
                    ? "\(Int(viewModel.estimatedCalories))"
                    : "--")
                    .font(.title3.monospacedDigit().bold())
                    .contentTransition(.numericText())
                    .animation(.default, value: Int(viewModel.estimatedCalories))
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Pause / Resume
            Button {
                if viewModel.state == .paused {
                    viewModel.resume()
                } else {
                    viewModel.pause()
                }
            } label: {
                Image(systemName: viewModel.state == .paused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.caution)
            .disabled(viewModel.state == .idle || viewModel.state == .finished)

            // End
            Button {
                showEndConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("End")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.negative)
            .disabled(viewModel.state == .idle || viewModel.state == .finished)
        }
    }
}
