import SwiftUI
import SwiftData

private struct ExerciseStartConfig: Identifiable {
    let id = UUID()
    let exercise: ExerciseDefinition
    let templateEntry: TemplateEntry?
}

struct ExerciseView: View {
    @State private var viewModel = ExerciseViewModel()
    @State private var showingExercisePicker = false
    @State private var exerciseStartConfig: ExerciseStartConfig?
    @State private var pendingDraft: WorkoutSessionDraft?
    @State private var showingTemplates = false
    @State private var workoutSuggestion: WorkoutSuggestion?
    @State private var showingCompoundSetup = false
    @State private var compoundConfig: CompoundWorkoutConfig?
    @State private var templateConfig: TemplateWorkoutConfig?
    @State private var recordToDelete: ExerciseRecord?
    @State private var healthKitWorkoutToDelete: WorkoutSummary?
    @State private var recordsByID: [UUID: ExerciseRecord] = [:]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var manualRecords: [ExerciseRecord]
    @Query(sort: \CustomExercise.createdAt, order: .reverse) private var customExercises: [CustomExercise]

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared
    private let recommendationService: WorkoutRecommending = WorkoutRecommendationService()

    var body: some View {
        let base = contentView

        return base
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingExercisePicker) { exercisePickerSheet }
            .sheet(item: $exerciseStartConfig, content: exerciseStartSheet)
            .sheet(isPresented: $showingCompoundSetup) {
                CompoundWorkoutSetupView(
                    library: library,
                    recentExerciseIDs: recentExerciseIDs
                ) { config in
                    compoundConfig = config
                }
            }
            .navigationDestination(item: $compoundConfig) { config in
                CompoundWorkoutView(config: config)
            }
            .fullScreenCover(item: $templateConfig) { config in
                TemplateWorkoutContainerView(config: config)
            }
            .task {
                pendingDraft = WorkoutSessionDraft.load()
                rebuildRecordIndex()
                WorkoutTypeCorrectionStore.shared.backfillTitles(from: manualRecords)
                viewModel.manualRecords = manualRecords
                updateSuggestion()
                await viewModel.loadHealthKitWorkouts()
            }
            .onChange(of: manualRecords) { _, newValue in
                rebuildRecordIndex()
                WorkoutTypeCorrectionStore.shared.backfillTitles(from: newValue)
                viewModel.manualRecords = newValue
                updateSuggestion()
            }
            .waveRefreshable(
                color: DS.Color.activity
            ) {
                await viewModel.loadHealthKitWorkouts()
            }
            .background { TabWaveBackground() }
            .englishNavigationTitle("Exercise")
            .alert(
                "Delete Exercise?",
                isPresented: Binding(
                    get: { healthKitWorkoutToDelete != nil },
                    set: { if !$0 { healthKitWorkoutToDelete = nil } }
                ),
                presenting: healthKitWorkoutToDelete
            ) { workout in
                Button("Delete", role: .destructive) {
                    deleteHealthKitWorkout(workout)
                }
                Button("Cancel", role: .cancel) {
                    healthKitWorkoutToDelete = nil
                }
            } message: { workout in
                Text("\(workout.localizedTitle) on \(workout.date.formatted(date: .abbreviated, time: .omitted)) will be permanently deleted from all your devices.")
            }
            .confirmDeleteRecord($recordToDelete, context: modelContext)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            NavigationLink {
                WorkoutTemplateListView { template in
                    startFromTemplate(template)
                }
            } label: {
                Image(systemName: "list.clipboard")
            }
            .accessibilityIdentifier("exercise-toolbar-templates")

            NavigationLink {
                UserCategoryManagementView()
            } label: {
                Image(systemName: "tag")
            }
            .accessibilityIdentifier("exercise-toolbar-categories")
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Single Exercise", systemImage: "figure.run")
                }
                Button {
                    showingCompoundSetup = true
                } label: {
                    Label("Superset / Circuit", systemImage: "arrow.triangle.2.circlepath")
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityIdentifier("exercise-toolbar-add")
        }
    }

    private var exercisePickerSheet: some View {
        ExercisePickerView(
            library: library,
            recentExerciseIDs: recentExerciseIDs,
            popularExerciseIDs: popularExerciseIDs,
            mode: .quickStart
        ) { exercise in
            presentExerciseStart(exercise)
        }
    }

    private func exerciseStartSheet(config: ExerciseStartConfig) -> some View {
        ExerciseStartView(
            exercise: config.exercise,
            templateEntry: config.templateEntry
        )
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            if viewModel.isLoading && viewModel.allExercises.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.allExercises.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    icon: "figure.run",
                    title: "No Exercises",
                    message: "Record your workouts or sync from Apple Health to track activity.",
                    actionTitle: "Add Exercise",
                    action: { showingExercisePicker = true }
                )
            } else {
                List {
                    // Draft recovery banner
                    if let draft = pendingDraft {
                        draftBanner(draft)
                    }

                    // AI workout suggestion
                    if let suggestion = workoutSuggestion, !suggestion.exercises.isEmpty {
                        Section {
                            SuggestedWorkoutCard(suggestion: suggestion) { exercise in
                                presentExerciseStart(exercise)
                            }
                            .listRowInsets(EdgeInsets())
                        }
                    }

                    ForEach(viewModel.allExercises) { item in
                        Group {
                            if item.source == .manual, let record = findRecord(for: item) {
                                NavigationLink {
                                    ExerciseSessionDetailView(
                                        record: record,
                                        activityType: item.activityType,
                                        displayName: item.displayName,
                                        equipment: item.equipment
                                    )
                                } label: {
                                    UnifiedWorkoutRow(item: item, style: .full)
                                }
                            } else if item.source == .healthKit, let summary = item.workoutSummary {
                                NavigationLink {
                                    HealthKitWorkoutDetailView(workout: summary)
                                } label: {
                                    UnifiedWorkoutRow(item: item, style: .full)
                                }
                            } else {
                                UnifiedWorkoutRow(item: item, style: .full)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if item.source == .manual {
                                Button {
                                    recordToDelete = findRecord(for: item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            } else if item.source == .healthKit,
                                      let summary = item.workoutSummary,
                                      summary.isFromThisApp {
                                Button {
                                    healthKitWorkoutToDelete = summary
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                        .onAppear {
                            // Trigger pagination when near the bottom
                            if item.id == viewModel.allExercises.last?.id {
                                Task {
                                    await viewModel.loadMoreWorkouts()
                                }
                            }
                        }
                    }

                    // Loading more indicator
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func startFromTemplate(_ template: WorkoutTemplate) {
        let entries = template.exerciseEntries
        guard !entries.isEmpty else { return }

        // Single exercise: use existing single-exercise flow
        if entries.count == 1 {
            if let definition = resolveExercise(from: entries[0]) {
                presentExerciseStart(definition, templateEntry: entries[0])
            }
            return
        }

        // Multi-exercise: resolve all and use template container
        let exercises = entries.compactMap { resolveExercise(from: $0) }
        guard !exercises.isEmpty else { return }

        templateConfig = TemplateWorkoutConfig(
            templateName: template.name,
            exercises: exercises,
            templateEntries: entries
        )
    }

    private func resolveExercise(from entry: TemplateEntry) -> ExerciseDefinition? {
        TemplateExerciseResolver.resolveExercise(
            for: entry,
            library: library,
            customExercises: customExercises
        )
    }

    private func updateSuggestion() {
        let snapshots = manualRecords.map { record -> ExerciseRecordSnapshot in
            var primary = record.primaryMuscles
            var secondary = record.secondaryMuscles

            // Backfill muscles from library for V1-migrated records with empty muscle data
            if primary.isEmpty, let defID = record.exerciseDefinitionID,
               let definition = library.exercise(byID: defID) {
                primary = definition.primaryMuscles
                secondary = definition.secondaryMuscles
            }

            return ExerciseRecordSnapshot(
                date: record.date,
                exerciseDefinitionID: record.exerciseDefinitionID,
                primaryMuscles: primary,
                secondaryMuscles: secondary,
                completedSetCount: record.completedSets.count
            )
        }
        workoutSuggestion = recommendationService.recommend(from: snapshots, library: library)
    }

    private func rebuildRecordIndex() {
        recordsByID = Dictionary(manualRecords.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    private func findRecord(for item: ExerciseListItem) -> ExerciseRecord? {
        guard let uuid = UUID(uuidString: item.id) else { return nil }
        return recordsByID[uuid]
    }

    private func presentExerciseStart(
        _ exercise: ExerciseDefinition,
        templateEntry: TemplateEntry? = nil
    ) {
        exerciseStartConfig = ExerciseStartConfig(
            exercise: exercise,
            templateEntry: templateEntry
        )
    }

    private var recentExerciseIDs: [String] {
        var seen = Set<String>()
        return manualRecords.compactMap { record in
            guard let id = record.exerciseDefinitionID, !seen.contains(id) else { return nil }
            seen.insert(id)
            return id
        }
    }

    private var popularExerciseIDs: [String] {
        let usages: [QuickStartPopularityService.Usage] = manualRecords.compactMap { record in
            guard let id = record.exerciseDefinitionID else { return nil }
            return .init(exerciseDefinitionID: id, date: record.date)
        }
        let historyBased = QuickStartPopularityService.popularExerciseIDs(
            from: usages,
            limit: 10,
            canonicalize: QuickStartCanonicalService.canonicalExerciseID(for:)
        )
        // Correction #189: fallback to curated defaults when history is insufficient
        guard !historyBased.isEmpty else {
            return QuickStartPopularityService.defaultPopularExerciseIDs
        }
        return historyBased
    }

    private func deleteHealthKitWorkout(_ workout: WorkoutSummary) {
        healthKitWorkoutToDelete = nil

        Task { @MainActor in
            let deleteService = WorkoutDeleteService(manager: .shared)
            do {
                try await deleteService.deleteWorkout(uuid: workout.id)
            } catch {
                AppLogger.healthKit.error("HealthKit-only workout delete failed: \(error.localizedDescription)")
                WatchSessionManager.shared.requestWatchWorkoutDeletion(workoutUUID: workout.id)
            }

            let linkedRecords = manualRecords.filter { $0.healthKitWorkoutID == workout.id }
            if !linkedRecords.isEmpty {
                withAnimation {
                    for record in linkedRecords {
                        modelContext.delete(record)
                    }
                }
            }

            await viewModel.loadHealthKitWorkouts()
        }
    }

    private func draftBanner(_ draft: WorkoutSessionDraft) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Unfinished Workout")
                    .font(.subheadline.weight(.medium))
                Text("\(draft.exerciseDefinition.localizedName) - \(draft.sets.filter(\.isCompleted).count.formattedWithSeparator) sets")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
            Button("Resume") {
                presentExerciseStart(draft.exerciseDefinition)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.activity)

            Button {
                WorkoutSessionViewModel.clearDraft()
                pendingDraft = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.md)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.orange.opacity(0.08))
    }
}

#Preview {
    ExerciseView()
        .modelContainer(for: [ExerciseRecord.self, WorkoutSet.self], inMemory: true)
}
