import SwiftUI
import SwiftData

struct ExerciseView: View {
    @State private var viewModel = ExerciseViewModel()
    @State private var showingExercisePicker = false
    @State private var selectedExercise: ExerciseDefinition?
    @State private var pendingDraft: WorkoutSessionDraft?
    @State private var showingTemplates = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var manualRecords: [ExerciseRecord]

    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared

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

                    ForEach(viewModel.allExercises) { item in
                        if let defID = item.exerciseDefinitionID {
                            NavigationLink {
                                ExerciseHistoryView(
                                    exerciseDefinitionID: defID,
                                    exerciseName: item.type
                                )
                            } label: {
                                ExerciseRowView(item: item)
                            }
                        } else {
                            ExerciseRowView(item: item)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    WorkoutTemplateListView { template in
                        startFromTemplate(template)
                    }
                } label: {
                    Image(systemName: "list.clipboard")
                }
                .accessibilityIdentifier("exercise-templates-button")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingExercisePicker = true
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
        .task {
            pendingDraft = WorkoutSessionDraft.load()
            viewModel.manualRecords = manualRecords
            await viewModel.loadHealthKitWorkouts()
        }
        .onChange(of: manualRecords) { _, newValue in
            viewModel.manualRecords = newValue
        }
        .navigationTitle("Exercise")
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
                    Text(item.type)
                        .font(.headline)
                    if item.source == .healthKit {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
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
