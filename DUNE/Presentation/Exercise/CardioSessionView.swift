import SwiftUI
import SwiftData

/// Full-screen live cardio tracking view for iPhone.
/// Mirrors Watch's CardioMetricsView layout adapted for larger screen.
/// Shows real-time: elapsed time, distance, pace, heart rate, calories.
struct CardioSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CardioSessionViewModel
    @State private var showEndConfirmation = false
    @State private var showingCompletionSheet = false
    @State private var savedRecord: ExerciseRecord?

    private let exercise: ExerciseDefinition

    init(exercise: ExerciseDefinition, isOutdoor: Bool) {
        self.exercise = exercise
        self._viewModel = State(
            initialValue: CardioSessionViewModel(exercise: exercise, isOutdoor: isOutdoor)
        )
    }

    var body: some View {
        mainContent
            .background { DetailWaveBackground() }
            .navigationTitle(exercise.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar { toolbarContent }
            .task { await viewModel.startSession() }
            .onDisappear { viewModel.cleanup() }
            .confirmationDialog(
                "End Workout?",
                isPresented: $showEndConfirmation,
                titleVisibility: .visible
            ) {
                endConfirmationActions
            } message: {
                Text("Save and finish this workout?")
            }
            .sheet(isPresented: $showingCompletionSheet, onDismiss: { dismiss() }) {
                completionSheet
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK") { viewModel.validationError = nil }
            } message: {
                Text(viewModel.validationError ?? "")
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                showEndConfirmation = true
            }
            .fontWeight(.semibold)
            .disabled(viewModel.sessionManager.state == .idle)
        }
    }

    @ViewBuilder
    private var endConfirmationActions: some View {
        Button("End Workout", role: .destructive) {
            Task { await endAndSave() }
        }
        Button("Cancel", role: .cancel) {}
    }

    private var completionSheet: some View {
        WorkoutCompletionSheet(
            shareImage: nil,
            exerciseName: exercise.localizedName,
            setCount: 1,
            effortSuggestion: nil,
            onDismiss: { selectedRPE in
                if let rpe = selectedRPE, (1...10).contains(rpe) {
                    savedRecord?.rpe = rpe
                }
                dismiss()
            }
        )
        .presentationDetents([.large])
    }

    private var errorBinding: Binding<Bool> {
        .init(
            get: { viewModel.validationError != nil },
            set: { if !$0 { viewModel.validationError = nil } }
        )
    }

    private var mainContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                headerSection(now: context.date)

                Divider()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        Spacer(minLength: DS.Spacing.xl)
                        distanceSection
                        secondaryMetricsGrid
                        Spacer(minLength: DS.Spacing.xl)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                }

                controlSection
            }
        }
    }

    // MARK: - Header

    private func headerSection(now: Date) -> some View {
        HStack {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: exercise.resolvedActivityType.iconName)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.activity)

                Text(exercise.localizedName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()

            // Elapsed time
            Text(formattedElapsedTime(at: now))
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(DS.Color.textSecondary)
                .contentTransition(.numericText())

            // State indicator
            if viewModel.sessionManager.state == .paused {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(DS.Color.caution)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    private func formattedElapsedTime(at now: Date) -> String {
        let elapsed = viewModel.sessionManager.activeElapsedTime(at: now)
        guard elapsed > 0 else { return "0:00" }
        let hours = Int(elapsed) / 3600
        let mins = (Int(elapsed) % 3600) / 60
        let secs = Int(elapsed) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Distance (Primary)

    private var distanceSection: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(String(format: "%.2f", viewModel.sessionManager.distanceKm))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DS.Color.positive)
                .contentTransition(.numericText())

            Text("km")
                .font(.title3.weight(.medium))
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Secondary Metrics

    private var secondaryMetricsGrid: some View {
        HStack(spacing: DS.Spacing.lg) {
            metricCard(
                icon: "speedometer",
                value: viewModel.sessionManager.formattedPace,
                unit: "/km",
                color: DS.Color.activity
            )

            metricCard(
                icon: "heart.fill",
                value: viewModel.sessionManager.heartRate > 0
                    ? "\(Int(viewModel.sessionManager.heartRate))"
                    : "--",
                unit: "bpm",
                color: DS.Color.heartRate
            )

            metricCard(
                icon: "flame.fill",
                value: viewModel.sessionManager.activeCalories > 0
                    ? "\(Int(viewModel.sessionManager.activeCalories))"
                    : "--",
                unit: "kcal",
                color: DS.Color.caution
            )
        }
    }

    private func metricCard(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())

            Text(unit)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Controls

    private var controlSection: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: DS.Spacing.lg) {
                // Pause / Resume
                Button {
                    if viewModel.sessionManager.state == .paused {
                        viewModel.resumeSession()
                    } else {
                        viewModel.pauseSession()
                    }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: viewModel.sessionManager.state == .paused
                              ? "play.fill" : "pause.fill")
                        Text(viewModel.sessionManager.state == .paused
                             ? "Resume" : "Pause")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .tint(DS.Color.caution)

                // End Workout
                Button {
                    showEndConfirmation = true
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "stop.fill")
                        Text("End")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.negative)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - End & Save

    private func endAndSave() async {
        await viewModel.endSession()

        guard let record = viewModel.createValidatedRecord() else { return }

        // Write to HealthKit (fire-and-forget if HK session didn't handle it)
        let hkUUID = viewModel.sessionManager.healthKitWorkoutUUID
        if let hkUUID, !hkUUID.isEmpty {
            record.healthKitWorkoutID = hkUUID
        } else if !record.isFromHealthKit {
            let input = WorkoutWriteInput(
                startDate: record.date,
                duration: record.duration,
                category: exercise.category,
                exerciseName: exercise.name,
                estimatedCalories: record.estimatedCalories,
                isFromHealthKit: record.isFromHealthKit,
                distanceKm: viewModel.sessionManager.distanceKm > 0.001
                    ? viewModel.sessionManager.distanceKm : nil,
                activityType: viewModel.sessionManager.activityType
            )
            Task {
                do {
                    let id = try await WorkoutWriteService().saveWorkout(input)
                    record.healthKitWorkoutID = id
                } catch {
                    AppLogger.healthKit.error("Failed to write cardio workout to HealthKit: \(error.localizedDescription)")
                }
            }
        }

        modelContext.insert(record)
        savedRecord = record
        viewModel.didFinishSaving()

        showingCompletionSheet = true
    }
}
