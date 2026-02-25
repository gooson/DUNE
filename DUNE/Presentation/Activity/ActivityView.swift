import SwiftUI
import SwiftData

/// Activity tab — redesigned recovery-centered dashboard.
/// Layout: Hero → Muscle Map → Weekly Stats → Suggestion → Volume → Workouts → PRs → Consistency → Frequency.
struct ActivityView: View {
    @State private var viewModel: ActivityViewModel
    @State private var showingExercisePicker = false
    @State private var selectedExercise: ExerciseDefinition?
    @State private var selectedMuscle: MuscleGroup?
    @State private var showingPRInfo = false
    @State private var showingConsistencyInfo = false
    @State private var showingExerciseMixInfo = false
    @Environment(\.modelContext) private var modelContext

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared

    @Query(sort: \ExerciseRecord.date, order: .reverse) private var recentRecords: [ExerciseRecord]
    @Query(filter: #Predicate<InjuryRecord> { $0.endDate == nil },
           sort: \InjuryRecord.startDate, order: .reverse) private var activeInjuryRecords: [InjuryRecord]

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var cachedInjuryConflicts: [InjuryConflict] = []
    private let conflictUseCase = CheckInjuryConflictUseCase()

    private var isRegular: Bool { sizeClass == .regular }

    init(sharedHealthDataService: SharedHealthDataService? = nil) {
        _viewModel = State(initialValue: ActivityViewModel(sharedHealthDataService: sharedHealthDataService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.isLoading && viewModel.weeklyExerciseMinutes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // ① Training Readiness Hero Card
                    NavigationLink(value: ActivityDetailDestination.trainingReadiness) {
                        TrainingReadinessHeroCard(
                            readiness: viewModel.trainingReadiness,
                            isCalibrating: viewModel.trainingReadiness?.isCalibrating ?? true
                        )
                    }
                    .buttonStyle(.plain)

                    // ② Injury Warning Banner
                    if !cachedInjuryConflicts.isEmpty {
                        InjuryWarningBanner(conflicts: cachedInjuryConflicts)
                    }

                    // ③④ Recovery Map + Weekly Stats (side-by-side on iPad)
                    if isRegular {
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            recoveryMapSection(fillHeight: true)
                            weeklyStatsSection(fillHeight: true)
                        }
                    } else {
                        recoveryMapSection()
                        weeklyStatsSection()
                    }

                    // ⑤⑥ Suggested Workout + Training Volume (side-by-side on iPad)
                    if isRegular {
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            suggestedWorkoutSection(fillHeight: true)
                            trainingVolumeSection(fillHeight: true)
                        }
                    } else {
                        suggestedWorkoutSection()
                        trainingVolumeSection()
                    }

                    // ⑦ Recent Workouts
                    SectionGroup(title: "Recent Workouts", icon: "clock.arrow.circlepath", iconColor: DS.Color.activity) {
                        ExerciseListSection(
                            workouts: viewModel.recentWorkouts,
                            exerciseRecords: recentRecords
                        )
                    }

                    // ⑧ Personal Records
                    SectionGroup(title: "Personal Records", icon: "trophy.fill",
                                 iconColor: DS.Color.activity,
                                 infoAction: { showingPRInfo = true }) {
                        NavigationLink(value: ActivityDetailDestination.personalRecords) {
                            PersonalRecordsSection(
                                records: viewModel.personalRecords,
                                notice: viewModel.personalRecordNotice
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // ⑨ Consistency
                    SectionGroup(title: "Consistency", icon: "flame.fill",
                                 iconColor: DS.Color.activity,
                                 infoAction: { showingConsistencyInfo = true }) {
                        NavigationLink(value: ActivityDetailDestination.consistency) {
                            ConsistencyCard(streak: viewModel.workoutStreak)
                        }
                        .buttonStyle(.plain)
                    }

                    // ⑩ Exercise Mix
                    SectionGroup(title: "Exercise Mix", icon: "chart.bar.xaxis",
                                 iconColor: DS.Color.activity,
                                 infoAction: { showingExerciseMixInfo = true }) {
                        NavigationLink(value: ActivityDetailDestination.exerciseMix) {
                            ExerciseFrequencySection(frequencies: viewModel.exerciseFrequencies)
                        }
                        .buttonStyle(.plain)
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
        .background { TabWaveBackground(primaryColor: DS.Color.activity) }
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
        .navigationDestination(for: ActivityDetailDestination.self) { destination in
            switch destination {
            case .personalRecords:
                PersonalRecordsDetailView(
                    records: viewModel.personalRecords,
                    notice: viewModel.personalRecordNotice
                )
            case .consistency:
                ConsistencyDetailView()
            case .exerciseMix:
                ExerciseMixDetailView()
            case .trainingReadiness:
                TrainingReadinessDetailView(
                    readiness: viewModel.trainingReadiness,
                    hrvDailyAverages: viewModel.hrvDailyAverages,
                    rhrDailyData: viewModel.rhrDailyData,
                    sleepDailyData: viewModel.sleepDailyData
                )
            case .weeklyStats:
                WeeklyStatsDetailView()
            }
        }
        .sheet(isPresented: $showingPRInfo) {
            PersonalRecordsInfoSheet()
        }
        .sheet(isPresented: $showingConsistencyInfo) {
            ConsistencyInfoSheet()
        }
        .sheet(isPresented: $showingExerciseMixInfo) {
            ExerciseMixInfoSheet()
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseStartView(exercise: exercise)
                .interactiveDismissDisabled()
        }
        .waveRefreshable(
            color: DS.Color.activity
        ) {
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

    // MARK: - Extracted Sections

    private func recoveryMapSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "Recovery Map", icon: "figure.stand", iconColor: DS.Color.activity, fillHeight: fillHeight) {
            MuscleRecoveryMapView(
                fatigueStates: viewModel.fatigueStates,
                onMuscleSelected: { muscle in selectedMuscle = muscle }
            )
        }
    }

    private func weeklyStatsSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "This Week", icon: "chart.bar.fill", iconColor: DS.Color.activity, fillHeight: fillHeight) {
            NavigationLink(value: ActivityDetailDestination.weeklyStats) {
                WeeklyStatsGrid(stats: viewModel.weeklyStats)
            }
            .buttonStyle(.plain)
        }
    }

    private func suggestedWorkoutSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "Suggested Workout", icon: "sparkles", iconColor: DS.Color.activity, fillHeight: fillHeight) {
            SuggestedWorkoutSection(
                suggestion: viewModel.workoutSuggestion,
                onStartExercise: { exercise in selectedExercise = exercise }
            )
        }
    }

    private func trainingVolumeSection(fillHeight: Bool = false) -> some View {
        SectionGroup(title: "Training Volume", icon: "chart.line.uptrend.xyaxis", iconColor: DS.Color.activity, fillHeight: fillHeight) {
            TrainingVolumeSummaryCard(
                trainingLoadData: viewModel.trainingLoadData,
                lastWorkoutMinutes: viewModel.lastWorkoutMinutes,
                lastWorkoutCalories: viewModel.lastWorkoutCalories
            )
        }
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
