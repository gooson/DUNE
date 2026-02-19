import SwiftUI
import SwiftData

/// Activity tab with recovery-centered dashboard.
/// Layout: WeeklyProgressBar → MuscleRecoveryMap (hero) → TrainingVolume → RecentWorkouts.
struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @State private var showingExercisePicker = false
    @State private var selectedExercise: ExerciseDefinition?
    @State private var selectedMuscle: MuscleGroup?
    @Environment(\.modelContext) private var modelContext

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared

    @Query(sort: \ExerciseRecord.date, order: .reverse) private var recentRecords: [ExerciseRecord]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.isLoading && viewModel.weeklyExerciseMinutes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // ① Weekly Progress Bar
                    WeeklyProgressBar(
                        activeDays: viewModel.activeDays,
                        goal: viewModel.weeklyGoal
                    )

                    // ② Muscle Recovery Map (hero)
                    MuscleRecoveryMapView(
                        fatigueStates: viewModel.fatigueStates,
                        suggestion: viewModel.workoutSuggestion,
                        onStartExercise: { exercise in selectedExercise = exercise },
                        onMuscleSelected: { muscle in selectedMuscle = muscle }
                    )

                    // ③ Training Volume Summary (compact)
                    TrainingVolumeSummaryCard(
                        trainingLoadData: viewModel.trainingLoadData,
                        lastWorkoutMinutes: viewModel.lastWorkoutMinutes,
                        lastWorkoutCalories: viewModel.lastWorkoutCalories
                    )

                    // ④ Recent Workouts
                    ExerciseListSection(
                        workouts: viewModel.recentWorkouts,
                        exerciseRecords: recentRecords
                    )

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
            }
            .padding()
        }
        .background {
            LinearGradient(
                colors: [DS.Color.activity.opacity(0.03), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingExercisePicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("activity-add-button")
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(
                library: library,
                recentExerciseIDs: recentExerciseIDs
            ) { exercise in
                selectedExercise = exercise
            }
        }
        .sheet(item: $selectedMuscle) { muscle in
            MuscleDetailPopover(
                muscle: muscle,
                fatigueState: viewModel.fatigueStates.first { $0.muscle == muscle },
                library: library
            )
        }
        .navigationDestination(for: HealthMetric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: AllDataDestination.self) { destination in
            AllDataView(category: destination.category)
        }
        .navigationDestination(for: TrainingVolumeDestination.self) { destination in
            switch destination {
            case .overview:
                TrainingVolumeDetailView()
            case .exerciseType(let typeKey, let displayName):
                ExerciseTypeDetailView(typeKey: typeKey, displayName: displayName)
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseStartView(exercise: exercise)
                .interactiveDismissDisabled()
        }
        .refreshable {
            await viewModel.loadActivityData()
        }
        // Correction #78: consolidate .task + .onChange → .task(id:)
        .task(id: recentRecords.count) {
            viewModel.updateSuggestion(records: recentRecords)
            await viewModel.loadActivityData()
        }
        .navigationTitle("Train")
    }

    // MARK: - Helpers

    private var recentExerciseIDs: [String] {
        var seen = Set<String>()
        return recentRecords.compactMap { record in
            guard let id = record.exerciseDefinitionID, !seen.contains(id) else { return nil }
            seen.insert(id)
            return id
        }
    }
}

#Preview {
    ActivityView()
        .modelContainer(for: [ExerciseRecord.self, WorkoutSet.self], inMemory: true)
}
