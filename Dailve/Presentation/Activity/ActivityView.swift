import SwiftUI
import SwiftData

/// Activity tab with unified training volume card, AI suggestions, and recent workouts.
struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @State private var showingExercisePicker = false
    @State private var selectedExercise: ExerciseDefinition?
    @Environment(\.modelContext) private var modelContext

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared

    @Query(sort: \ExerciseRecord.date, order: .reverse) private var recentRecords: [ExerciseRecord]

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                if viewModel.isLoading && viewModel.weeklyExerciseMinutes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // AI Workout Suggestion
                    if let suggestion = viewModel.workoutSuggestion,
                       !suggestion.exercises.isEmpty {
                        SuggestedWorkoutCard(suggestion: suggestion) { exercise in
                            selectedExercise = exercise
                        }
                    }

                    // Training Volume (unified card, 28-day training load)
                    TrainingVolumeSummaryCard(
                        trainingLoadData: viewModel.trainingLoadData,
                        lastWorkoutMinutes: viewModel.lastWorkoutMinutes,
                        lastWorkoutCalories: viewModel.lastWorkoutCalories,
                        activeDays: viewModel.activeDays,
                        weeklyGoal: viewModel.weeklyGoal
                    )

                    // Recent Workouts
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
        .task {
            viewModel.updateSuggestion(records: recentRecords)
            await viewModel.loadActivityData()
        }
        .onChange(of: recentRecords.count) { _, _ in
            viewModel.updateSuggestion(records: recentRecords)
        }
        .navigationTitle("Train")
    }

    // MARK: - Helpers

    private var recentExerciseIDs: [String] {
        // Unique exercise definition IDs from recent records, ordered by most recent
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
