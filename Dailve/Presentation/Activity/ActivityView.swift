import SwiftUI
import SwiftData

/// Activity tab — redesigned recovery-centered dashboard.
/// Layout: Hero → Muscle Map → Weekly Stats → Suggestion → Volume → Workouts → PRs → Consistency → Frequency.
struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @State private var showingExercisePicker = false
    @State private var selectedExercise: ExerciseDefinition?
    @State private var selectedMuscle: MuscleGroup?
    @Environment(\.modelContext) private var modelContext

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared

    @Query(sort: \ExerciseRecord.date, order: .reverse) private var recentRecords: [ExerciseRecord]
    @Query(filter: #Predicate<InjuryRecord> { $0.endDate == nil },
           sort: \InjuryRecord.startDate, order: .reverse) private var activeInjuryRecords: [InjuryRecord]

    @State private var cachedInjuryConflicts: [InjuryConflict] = []
    private let conflictUseCase = CheckInjuryConflictUseCase()

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.isLoading && viewModel.weeklyExerciseMinutes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // ① Training Readiness Hero Card
                    TrainingReadinessHeroCard(
                        readiness: viewModel.trainingReadiness,
                        isCalibrating: viewModel.trainingReadiness?.isCalibrating ?? true
                    )

                    // ② Injury Warning Banner
                    if !cachedInjuryConflicts.isEmpty {
                        InjuryWarningBanner(conflicts: cachedInjuryConflicts)
                    }

                    // ③ Muscle Recovery Map
                    SectionGroup(title: "Recovery Map", icon: "figure.stand", iconColor: DS.Color.activity) {
                        MuscleRecoveryMapView(
                            fatigueStates: viewModel.fatigueStates,
                            onMuscleSelected: { muscle in selectedMuscle = muscle }
                        )
                    }

                    // ④ Weekly Stats Grid
                    SectionGroup(title: "This Week", icon: "chart.bar.fill", iconColor: DS.Color.activity) {
                        WeeklyStatsGrid(stats: viewModel.weeklyStats)
                    }

                    // ⑤ Suggested Workout
                    SectionGroup(title: "Suggested Workout", icon: "sparkles", iconColor: DS.Color.activity) {
                        SuggestedWorkoutSection(
                            suggestion: viewModel.workoutSuggestion,
                            onStartExercise: { exercise in selectedExercise = exercise }
                        )
                    }

                    // ⑥ Training Volume Summary
                    SectionGroup(title: "Training Volume", icon: "chart.line.uptrend.xyaxis", iconColor: DS.Color.activity) {
                        TrainingVolumeSummaryCard(
                            trainingLoadData: viewModel.trainingLoadData,
                            lastWorkoutMinutes: viewModel.lastWorkoutMinutes,
                            lastWorkoutCalories: viewModel.lastWorkoutCalories
                        )
                    }

                    // ⑦ Recent Workouts
                    ExerciseListSection(
                        workouts: viewModel.recentWorkouts,
                        exerciseRecords: recentRecords
                    )

                    // ⑧ Personal Records
                    SectionGroup(title: "Personal Records", icon: "trophy.fill", iconColor: DS.Color.activity) {
                        PersonalRecordsSection(records: viewModel.personalRecords)
                    }

                    // ⑨ Consistency & Frequency
                    SectionGroup(title: "Consistency", icon: "flame.fill", iconColor: DS.Color.activity) {
                        ConsistencyCard(streak: viewModel.workoutStreak)
                    }

                    SectionGroup(title: "Exercise Mix", icon: "chart.bar.xaxis", iconColor: DS.Color.activity) {
                        ExerciseFrequencySection(frequencies: viewModel.exerciseFrequencies)
                    }

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
            recomputeInjuryConflicts()
        }
        .onChange(of: activeInjuryRecords.count) { _, _ in
            recomputeInjuryConflicts()
        }
        .navigationTitle("Activity")
    }

    // MARK: - Helpers

    private func recomputeInjuryConflicts() {
        guard !activeInjuryRecords.isEmpty else {
            cachedInjuryConflicts = []
            return
        }
        let suggestedMuscles = viewModel.workoutSuggestion?.focusMuscles ?? []
        guard !suggestedMuscles.isEmpty else {
            cachedInjuryConflicts = []
            return
        }
        let infos = activeInjuryRecords.filter(\.isActive).map { $0.toInjuryInfo() }
        let result = conflictUseCase.execute(input: .init(
            exerciseMuscles: suggestedMuscles,
            activeInjuries: infos
        ))
        cachedInjuryConflicts = result.conflicts
    }

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
        .modelContainer(for: [ExerciseRecord.self, WorkoutSet.self, InjuryRecord.self], inMemory: true)
}
