import SwiftUI
import SwiftData

/// Post-workout summary for cardio sessions. Saves ExerciseRecord and HKWorkout.
struct CardioSessionSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let viewModel: CardioSessionViewModel
    let exercise: ExerciseDefinition
    let onComplete: () -> Void

    @State private var isSaving = false
    @State private var hasSaved = false
    @State private var showsSaveError = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                completionHeader
                metricsGrid
                CardioMachineLevelHistoryView(changes: viewModel.machineLevelChanges)
            }
            .padding(DS.Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            saveButton
                .padding(DS.Spacing.lg)
                .background(.regularMaterial)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cardio-session-summary-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Error", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Could not save the workout. Please try again.")
        }
    }

    // MARK: - Completion Header

    private var completionHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DS.Color.positive)

            Text(exercise.localizedName)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("Workout Complete!")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Results

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if viewModel.showsDistance {
                primaryResult(
                    title: "Distance",
                    value: "\(viewModel.formattedDistance) km"
                )
                .accessibilityIdentifier("cardio-summary-distance")

                Text(viewModel.formattedElapsed)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .accessibilityIdentifier("cardio-summary-duration")
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            } else {
                primaryResult(title: "Duration", value: viewModel.formattedElapsed)
                    .accessibilityIdentifier("cardio-summary-duration")
            }

            VStack(spacing: 0) {
                if viewModel.showsDistance {
                    metricRow(title: "Avg Pace", value: "\(viewModel.formattedPace) /km")
                } else if viewModel.supportsMachineLevel {
                    metricRow(title: "Avg Level", value: viewModel.formattedAverageMachineLevel)
                }
                metricRow(title: "Calories", value: "\(Int(viewModel.estimatedCalories)) kcal")
                metricRow(title: "Steps", value: summaryStepsValue)
                if viewModel.supportsMachineLevel {
                    metricRow(title: "Max Level", value: viewModel.formattedMaxMachineLevel)
                } else {
                    metricRow(
                        title: "Cadence",
                        value: viewModel.cadenceStepsPerMinute > 0
                            ? "\(Int(viewModel.cadenceStepsPerMinute)) spm" : "--"
                    )
                }
                if viewModel.totalElevationGainMeters > 0 {
                    metricRow(title: "Elevation Gain", value: "\(Int(viewModel.totalElevationGainMeters)) m")
                }
                if let vo2Max = viewModel.cardioFitnessVO2Max {
                    metricRow(title: "Cardio Fitness", value: "\(String(format: "%.1f", vo2Max)) ml/kg/min")
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .background(DS.Color.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .accessibilityIdentifier("cardio-summary-secondary-metrics")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryStepsValue: String {
        if viewModel.activityType == .walking, viewModel.walkingStepCount > 0 {
            return "\(Int(viewModel.walkingStepCount).formattedWithSeparator) steps"
        }
        return viewModel.formattedStepCount
    }

    private func primaryResult(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(value)
                .font(.largeTitle.weight(.bold).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func metricRow(title: LocalizedStringKey, value: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.sm))
        return layout {
            Text(title)
                .foregroundStyle(DS.Color.textSecondary)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: DS.Spacing.sm) }
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
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
        .foregroundStyle(DS.Color.onBrightAction)
        .disabled(isSaving || hasSaved)
        .accessibilityIdentifier("cardio-session-summary-save")
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
            cardioMachineLevelChanges: data.cardioMachineLevelChanges,
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
        let locationRecord = WorkoutLocationRecord(localRecordID: record.id, payload: data.locationPayload)
        modelContext.insert(locationRecord)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(locationRecord)
            modelContext.delete(record)
            isSaving = false
            showsSaveError = true
            AppLogger.healthKit.error("Could not save cardio workout locally: \(error)")
            return
        }
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
            activityType: viewModel.activityType,
            isIndoor: data.locationPayload.isIndoor,
            routePoints: data.locationPayload.route,
            endDate: data.endDate,
            pauseIntervals: data.pauseIntervals
        )

        let recordID = record.persistentModelID
        Task { @MainActor in
            do {
                let hkID = try await WorkoutWriteService().saveWorkout(input)
                if let liveRecord = modelContext.model(for: recordID) as? ExerciseRecord {
                    liveRecord.healthKitWorkoutID = hkID
                    locationRecord.healthKitWorkoutID = hkID
                    locationRecord.updatedAt = Date()
                    try modelContext.save()
                }
            } catch {
                AppLogger.healthKit.error("Failed to write cardio workout to HealthKit: \(error)")
            }

            // Dismiss the entire sheet after HK write completes (or fails)
            onComplete()
        }
    }
}
