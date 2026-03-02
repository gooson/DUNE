import SwiftUI
import SwiftData

/// Full-screen cardio session with real-time timer, distance, pace, HR, and calories.
struct CardioSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CardioSessionViewModel
    @State private var showEndConfirmation = false
    @State private var showSummary = false

    let exercise: ExerciseDefinition

    init(exercise: ExerciseDefinition, activityType: WorkoutActivityType, isOutdoor: Bool) {
        self.exercise = exercise
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
        .navigationBarBackButtonHidden(viewModel.state != .idle)
        .toolbar {
            if viewModel.state != .idle {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showEndConfirmation = true }
                        .fontWeight(.semibold)
                }
            }
        }
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
            CardioSessionSummaryView(viewModel: viewModel, exercise: exercise)
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
            Button("OK") { viewModel.errorMessage = nil }
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
        HStack(spacing: DS.Spacing.xxs) {
            Circle()
                .fill(viewModel.state == .paused ? DS.Color.caution : DS.Color.positive)
                .frame(width: 8, height: 8)
            Text(viewModel.state == .paused
                 ? String(localized: "Paused")
                 : String(localized: "Active"))
                .font(.caption.weight(.medium))
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Primary: Elapsed Time

    private var primaryMetric: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: DS.Spacing.xxs) {
                Text(viewModel.formattedElapsed)
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())

                Text("Elapsed Time")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
            }
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
                Text("km")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            VStack(spacing: DS.Spacing.xxs) {
                Text(viewModel.formattedPace)
                    .font(.system(.title, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(DS.Color.activity)
                    .contentTransition(.numericText())
                Text("/km")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    // MARK: - Secondary Metrics

    private var secondaryMetrics: some View {
        HStack(spacing: DS.Spacing.xl) {
            metricColumn(
                value: viewModel.estimatedCalories > 0
                    ? "\(Int(viewModel.estimatedCalories))"
                    : "--",
                unit: "kcal",
                icon: "flame.fill",
                color: DS.Color.caution
            )
        }
    }

    private func metricColumn(value: String, unit: String, icon: String, color: SwiftUI.Color) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.monospacedDigit().bold())
                .contentTransition(.numericText())
            Text(unit)
                .font(.caption2)
                .foregroundStyle(DS.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
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
