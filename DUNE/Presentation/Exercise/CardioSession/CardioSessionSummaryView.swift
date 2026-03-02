import SwiftUI
import SwiftData

/// Post-workout summary for cardio sessions. Saves ExerciseRecord and HKWorkout.
struct CardioSessionSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let viewModel: CardioSessionViewModel
    let exercise: ExerciseDefinition

    @State private var isSaving = false
    @State private var hasSaved = false

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            completionHeader

            metricsGrid

            Spacer()

            saveButton
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
        .background { DetailWaveBackground() }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Completion Header

    private var completionHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DS.Color.positive)

            Text("Workout Complete!")
                .font(.title2.weight(.bold))

            Text(exercise.localizedName)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                summaryCard(
                    title: String(localized: "Duration"),
                    value: viewModel.formattedElapsed,
                    icon: "timer",
                    color: DS.Color.activity
                )

                if viewModel.showsDistance {
                    summaryCard(
                        title: String(localized: "Distance"),
                        value: "\(viewModel.formattedDistance) km",
                        icon: "location.fill",
                        color: DS.Color.positive
                    )
                }
            }

            HStack(spacing: DS.Spacing.md) {
                if viewModel.showsDistance {
                    summaryCard(
                        title: String(localized: "Avg Pace"),
                        value: "\(viewModel.formattedPace) /km",
                        icon: "speedometer",
                        color: DS.Color.activity
                    )
                }

                summaryCard(
                    title: String(localized: "Calories"),
                    value: "\(Int(viewModel.estimatedCalories)) kcal",
                    icon: "flame.fill",
                    color: DS.Color.caution
                )
            }
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: SwiftUI.Color) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())

            Text(title)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Color.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            saveWorkout()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text("Save Workout")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.Color.activity)
        .disabled(isSaving || hasSaved)
    }

    private func saveWorkout() {
        guard !isSaving, !hasSaved else { return }
        isSaving = true

        guard let data = viewModel.createExerciseRecord() else {
            isSaving = false
            return
        }

        let record = ExerciseRecord(
            date: data.startDate,
            exerciseType: data.exerciseName,
            duration: data.duration,
            distance: data.distanceKm,
            exerciseDefinitionID: data.exerciseID,
            primaryMuscles: exercise.primaryMuscles,
            secondaryMuscles: exercise.secondaryMuscles,
            equipment: exercise.equipment,
            estimatedCalories: data.estimatedCalories,
            calorieSource: .met
        )

        modelContext.insert(record)
        hasSaved = true
        isSaving = false

        // Fire-and-forget HealthKit write
        let input = WorkoutWriteInput(
            startDate: data.startDate,
            duration: data.duration,
            category: data.category,
            exerciseName: data.exerciseName,
            estimatedCalories: data.estimatedCalories,
            isFromHealthKit: false,
            totalDistanceMeters: viewModel.totalDistanceMeters > 0 ? viewModel.totalDistanceMeters : nil
        )

        Task {
            do {
                let hkID = try await WorkoutWriteService().saveWorkout(input)
                record.healthKitWorkoutID = hkID
            } catch {
                AppLogger.healthKit.error("Failed to write cardio workout to HealthKit: \(error.localizedDescription)")
            }
        }

        // Dismiss back to root after brief delay
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            dismiss()
        }
    }
}
