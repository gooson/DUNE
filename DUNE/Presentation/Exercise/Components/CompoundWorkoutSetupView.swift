import SwiftUI
import SwiftData

struct CompoundWorkoutSetupDraft {
    var selectedExercises: [ExerciseDefinition] = []
    var mode: CompoundWorkoutMode = .superset
    var totalRounds: Int = 3
    var restBetweenExercises: Int = 30
}

/// Setup screen for creating a superset or circuit workout
struct CompoundWorkoutSetupView: View {
    let library: ExerciseLibraryQuerying
    let recentExerciseIDs: [String]
    let onStart: (CompoundWorkoutConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @Binding var draft: CompoundWorkoutSetupDraft
    @State private var showingPicker = false

    private var isValid: Bool {
        draft.selectedExercises.count >= 2
    }

    var body: some View {
        NavigationStack {
            List {
                modeSection
                exercisesSection
                settingsSection
                startButton
            }
            .accessibilityIdentifier("compound-workout-setup-screen")
            .scrollContentBackground(.hidden)
            .englishNavigationTitle("Compound Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPicker) {
                CompoundExercisePickerSheet(
                    library: library,
                    recentExerciseIDs: recentExerciseIDs,
                    selectedExercises: $draft.selectedExercises,
                    isPresented: $showingPicker
                )
            }
            .background { SheetWaveBackground() }
        }
    }

    // MARK: - Mode

    private var modeSection: some View {
        Section {
            Picker("Mode", selection: $draft.mode) {
                Text("Superset").tag(CompoundWorkoutMode.superset)
                Text("Circuit").tag(CompoundWorkoutMode.circuit)
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(draft.mode == .superset
                ? "Alternate between 2 exercises with minimal rest."
                : "Cycle through 3+ exercises in rounds.")
        }
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        Section {
            ForEach(draft.selectedExercises) { exercise in
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(exercise.localizedName)
                            .font(.body)
                        Text(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("compound-workout-setup-row-\(exercise.id)")
            }
            .onDelete { indexSet in
                draft.selectedExercises.remove(atOffsets: indexSet)
            }
            .onMove { source, destination in
                draft.selectedExercises.move(fromOffsets: source, toOffset: destination)
            }

            Button {
                showingPicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus.circle.fill")
                    .foregroundStyle(DS.Color.activity)
            }
            .accessibilityIdentifier("compound-workout-setup-add-exercise")
        } header: {
            Text("Exercises (\(draft.selectedExercises.count))")
                .accessibilityIdentifier("compound-workout-setup-selection-count")
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        Section("Settings") {
            Stepper("Rounds: \(draft.totalRounds)", value: $draft.totalRounds, in: 1...10)
            Stepper("Rest: \(draft.restBetweenExercises)s", value: $draft.restBetweenExercises, in: 0...120, step: 15)
        }
    }

    // MARK: - Start

    private var startButton: some View {
        Section {
            Button {
                let config = CompoundWorkoutConfig(
                    exercises: draft.selectedExercises,
                    mode: draft.mode,
                    totalRounds: draft.totalRounds,
                    restBetweenExercises: draft.restBetweenExercises
                )
                onStart(config)
                dismiss()
            } label: {
                Text("Start Workout")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        isValid ? DS.Color.activity : Color.secondary,
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                    )
            }
            .disabled(!isValid)
            .accessibilityIdentifier("compound-workout-setup-start")
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

private struct CompoundExercisePickerSheet: View {
    let library: ExerciseLibraryQuerying
    let recentExerciseIDs: [String]
    @Binding var selectedExercises: [ExerciseDefinition]
    @Binding var isPresented: Bool

    var body: some View {
        ExercisePickerView(
            library: library,
            recentExerciseIDs: recentExerciseIDs,
            mode: .full
        ) { exercise in
            if !selectedExercises.contains(where: { $0.id == exercise.id }) {
                selectedExercises.append(exercise)
            }
            isPresented = false
        }
    }
}
