import SwiftUI
import SwiftData

struct ExerciseView: View {
    @State private var viewModel = ExerciseViewModel()
    @State private var showingExercisePicker = false
    @State private var selectedExercise: ExerciseDefinition?
    @State private var pendingDraft: WorkoutSessionDraft?
    @State private var showingTemplates = false
    @State private var workoutSuggestion: WorkoutSuggestion?
    @State private var showingCompoundSetup = false
    @State private var compoundConfig: CompoundWorkoutConfig?
    @State private var recordToDelete: ExerciseRecord?
    @State private var recordsByID: [UUID: ExerciseRecord] = [:]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var manualRecords: [ExerciseRecord]

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared
    private let recommendationService: WorkoutRecommending = WorkoutRecommendationService()

    var body: some View {
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
                                selectedExercise = exercise
                            }
                            .listRowInsets(EdgeInsets())
                        }
                    }

                    ForEach(viewModel.allExercises) { item in
                        Group {
                            if item.source == .manual, let record = findRecord(for: item) {
                                // Manual records navigate directly to session detail
                                NavigationLink {
                                    ExerciseSessionDetailView(record: record)
                                } label: {
                                    ExerciseRowView(item: item)
                                }
                            } else if let defID = item.exerciseDefinitionID {
                                // HealthKit-only items navigate to exercise history
                                NavigationLink {
                                    ExerciseHistoryView(
                                        exerciseDefinitionID: defID,
                                        exerciseName: item.localizedType ?? item.type
                                    )
                                } label: {
                                    ExerciseRowView(item: item)
                                }
                            } else {
                                ExerciseRowView(item: item)
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
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                NavigationLink {
                    WorkoutTemplateListView { template in
                        startFromTemplate(template)
                    }
                } label: {
                    Image(systemName: "list.clipboard")
                }
                .accessibilityIdentifier("exercise-templates-button")

                NavigationLink {
                    MuscleMapView()
                } label: {
                    Image(systemName: "figure.stand")
                }
                .accessibilityIdentifier("exercise-muscle-map-button")

                NavigationLink {
                    VolumeAnalysisView()
                } label: {
                    Image(systemName: "chart.bar.fill")
                }
                .accessibilityIdentifier("exercise-volume-analysis-button")

                NavigationLink {
                    UserCategoryManagementView()
                } label: {
                    Image(systemName: "tag")
                }
                .accessibilityIdentifier("exercise-categories-button")
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
                .accessibilityIdentifier("exercise-add-button")
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
        .navigationDestination(item: $selectedExercise) { exercise in
            WorkoutSessionView(exercise: exercise)
        }
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
        .task {
            pendingDraft = WorkoutSessionDraft.load()
            rebuildRecordIndex()
            viewModel.manualRecords = manualRecords
            updateSuggestion()
            await viewModel.loadHealthKitWorkouts()
        }
        .onChange(of: manualRecords) { _, newValue in
            rebuildRecordIndex()
            viewModel.manualRecords = newValue
            updateSuggestion()
        }
        .refreshable {
            await viewModel.loadHealthKitWorkouts()
        }
        .navigationTitle("Exercise")
        .confirmDeleteRecord($recordToDelete, context: modelContext)
    }

    private func startFromTemplate(_ template: WorkoutTemplate) {
        guard let firstEntry = template.exerciseEntries.first else { return }
        // Look up in library first, then custom exercises
        if let definition = library.exercise(byID: firstEntry.exerciseDefinitionID) {
            selectedExercise = definition
        } else if firstEntry.exerciseDefinitionID.hasPrefix("custom-") {
            // Custom exercise — build definition from entry name
            let definition = ExerciseDefinition(
                id: firstEntry.exerciseDefinitionID,
                name: firstEntry.exerciseName,
                localizedName: firstEntry.exerciseName,
                category: .strength,
                inputType: .setsRepsWeight,
                primaryMuscles: [],
                secondaryMuscles: [],
                equipment: .bodyweight,
                metValue: 5.0
            )
            selectedExercise = definition
        }
    }

    private func updateSuggestion() {
        let snapshots = manualRecords.map { record in
            ExerciseRecordSnapshot(
                date: record.date,
                exerciseDefinitionID: record.exerciseDefinitionID,
                primaryMuscles: record.primaryMuscles,
                secondaryMuscles: record.secondaryMuscles,
                completedSetCount: record.completedSets.count
            )
        }
        workoutSuggestion = recommendationService.recommend(from: snapshots, library: library)
    }

    private func rebuildRecordIndex() {
        recordsByID = Dictionary(uniqueKeysWithValues: manualRecords.map { ($0.id, $0) })
    }

    private func findRecord(for item: ExerciseListItem) -> ExerciseRecord? {
        guard let uuid = UUID(uuidString: item.id) else { return nil }
        return recordsByID[uuid]
    }

    private var recentExerciseIDs: [String] {
        var seen = Set<String>()
        return manualRecords.compactMap { record in
            guard let id = record.exerciseDefinitionID, !seen.contains(id) else { return nil }
            seen.insert(id)
            return id
        }
    }

    private func draftBanner(_ draft: WorkoutSessionDraft) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Unfinished Workout")
                    .font(.subheadline.weight(.medium))
                Text("\(draft.exerciseDefinition.localizedName) - \(draft.sets.filter(\.isCompleted).count) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Resume") {
                selectedExercise = draft.exerciseDefinition
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
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.md)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.orange.opacity(0.08))
    }
}

// MARK: - Row

private struct ExerciseRowView: View {
    let item: ExerciseListItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.localizedType ?? item.type)
                        .font(.headline)
                    if item.source == .healthKit {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    } else if item.isLinkedToHealthKit {
                        Image(systemName: "heart.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.6))
                    }
                }
                if let localized = item.localizedType, localized != item.type {
                    Text(item.type)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(item.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let summary = item.setSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let cal = item.calories {
                    Text("\(Int(cal)) kcal")
                        .font(.subheadline)
                }
                Text(item.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ExerciseView()
        .modelContainer(for: [ExerciseRecord.self, WorkoutSet.self], inMemory: true)
}
