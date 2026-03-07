import SwiftUI
import SwiftData

/// Post-workout summary for cardio sessions. Saves ExerciseRecord and HKWorkout.
struct CardioSessionSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let viewModel: CardioSessionViewModel
    let exercise: ExerciseDefinition
    let onComplete: () -> Void

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
        .englishNavigationTitle("Summary")
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
                    title: "Duration",
                    value: viewModel.formattedElapsed,
                    icon: "timer",
                    color: DS.Color.activity
                )

                if viewModel.showsDistance {
                    summaryCard(
                        title: "Distance",
                        value: "\(viewModel.formattedDistance) km",
                        icon: "location.fill",
                        color: DS.Color.positive
                    )
                }
            }

            HStack(spacing: DS.Spacing.md) {
                if viewModel.showsDistance {
                    summaryCard(
                        title: "Avg Pace",
                        value: "\(viewModel.formattedPace) /km",
                        icon: "speedometer",
                        color: DS.Color.activity
                    )
                } else if viewModel.supportsMachineLevel {
                    summaryCard(
                        title: "Avg Level",
                        value: viewModel.formattedAverageMachineLevel,
                        icon: "sum",
                        color: DS.Color.activity
                    )
                }

                summaryCard(
                    title: "Calories",
                    value: "\(Int(viewModel.estimatedCalories)) kcal",
                    icon: "flame.fill",
                    color: DS.Color.caution
                )
            }

            HStack(spacing: DS.Spacing.md) {
                summaryCard(
                    title: "Steps",
                    value: summaryStepsValue,
                    icon: "figure.walk",
                    color: DS.Color.steps
                )

                if viewModel.supportsMachineLevel {
                    summaryCard(
                        title: "Max Level",
                        value: viewModel.formattedMaxMachineLevel,
                        icon: "arrow.up.circle.fill",
                        color: DS.Color.activity
                    )
                } else {
                    summaryCard(
                        title: "Cadence",
                        value: viewModel.cadenceStepsPerMinute > 0
                            ? "\(Int(viewModel.cadenceStepsPerMinute)) spm"
                            : "--",
                        icon: "gauge.with.dots.needle.50percent",
                        color: DS.Color.activity
                    )
                }
            }

            let hasElevation = viewModel.totalElevationGainMeters > 0
            let hasVO2Max = viewModel.cardioFitnessVO2Max != nil

            if hasElevation || hasVO2Max {
                HStack(spacing: DS.Spacing.md) {
                    if hasElevation {
                        summaryCard(
                            title: "Elevation Gain",
                            value: "\(Int(viewModel.totalElevationGainMeters)) m",
                            icon: "mountain.2.fill",
                            color: DS.Color.positive
                        )
                    }

                    if let vo2Max = viewModel.cardioFitnessVO2Max {
                        summaryCard(
                            title: "Cardio Fitness",
                            value: "\(String(format: "%.1f", vo2Max)) ml/kg/min",
                            icon: "heart.circle.fill",
                            color: DS.Color.heartRate
                        )
                    }

                    if !(hasElevation && hasVO2Max) {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var summaryStepsValue: String {
        if viewModel.activityType == .walking, viewModel.walkingStepCount > 0 {
            return "\(Int(viewModel.walkingStepCount).formattedWithSeparator) steps"
        }
        return viewModel.formattedStepCount
    }

    private func summaryCard(title: LocalizedStringKey, value: String, icon: String, color: SwiftUI.Color) -> some View {
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
            Text(hasSaved ? "Saved!" : "Save Workout")
                .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .animation(DS.Animation.snappy, value: hasSaved)
        }
        .buttonStyle(.borderedProminent)
        .tint(hasSaved ? DS.Color.positive : DS.Color.activity)
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
            exerciseType: data.exerciseID,
            duration: data.duration,
            distance: data.distanceKm,
            stepCount: data.stepCount,
            averagePaceSecondsPerKm: data.averagePaceSecondsPerKm,
            averageCadenceStepsPerMinute: data.averageCadenceStepsPerMinute,
            elevationGainMeters: data.elevationGainMeters,
            floorsAscended: data.floorsAscended,
            cardioMachineLevelAverage: data.cardioMachineLevelAverage,
            cardioMachineLevelMax: data.cardioMachineLevelMax,
            exerciseDefinitionID: data.exerciseID,
            primaryMuscles: exercise.primaryMuscles,
            secondaryMuscles: exercise.secondaryMuscles,
            equipment: exercise.equipment,
            estimatedCalories: data.estimatedCalories,
            calorieSource: .met,
            autoIntensityRaw: data.autoIntensityRaw,
            cardioFitnessVO2Max: data.cardioFitnessVO2Max.flatMap { (10.0...90.0).contains($0) ? $0 : nil }
        )

        modelContext.insert(record)
        hasSaved = true
        isSaving = false

        // HealthKit write with proper MainActor isolation for SwiftData model
        let input = WorkoutWriteInput(
            startDate: data.startDate,
            duration: data.duration,
            category: data.category,
            exerciseName: data.exerciseName,
            estimatedCalories: data.estimatedCalories,
            isFromHealthKit: false,
            distanceKm: data.distanceKm,
            stepCount: data.stepCount,
            averagePaceSecondsPerKm: data.averagePaceSecondsPerKm,
            averageCadenceStepsPerMinute: data.averageCadenceStepsPerMinute,
            elevationGainMeters: data.elevationGainMeters,
            floorsAscended: data.floorsAscended,
            activityType: viewModel.activityType
        )

        let recordID = record.persistentModelID
        Task { @MainActor in
            do {
                let hkID = try await WorkoutWriteService().saveWorkout(input)
                if let liveRecord = modelContext.model(for: recordID) as? ExerciseRecord {
                    liveRecord.healthKitWorkoutID = hkID
                }
            } catch {
                AppLogger.healthKit.error("Failed to write cardio workout to HealthKit: \(error)")
            }

            // Dismiss the entire sheet after HK write completes (or fails)
            onComplete()
        }
    }
}
