import SwiftUI
import SwiftData

/// Setup screen for creating a superset or circuit workout
struct CompoundWorkoutSetupView: View {
    let library: ExerciseLibraryQuerying
    let recentExerciseIDs: [String]
    let onStart: (CompoundWorkoutConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercises: [ExerciseDefinition] = []
    @State private var mode: CompoundWorkoutMode = .superset
    @State private var totalRounds: Int = 3
    @State private var restBetweenExercises: Int = 30
    @State private var showingPicker = false

    private var isValid: Bool {
        selectedExercises.count >= 2
    }

    var body: some View {
        NavigationStack {
            List {
                modeSection
                exercisesSection
                settingsSection
                startButton
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Compound Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView(
                    library: library,
                    recentExerciseIDs: recentExerciseIDs,
                    mode: .full
                ) { exercise in
                    if !selectedExercises.contains(where: { $0.id == exercise.id }) {
                        selectedExercises.append(exercise)
                    }
                }
            }
            .background { SheetWaveBackground() }
        }
    }

    // MARK: - Mode

    private var modeSection: some View {
        Section {
            Picker("Mode", selection: $mode) {
                Text("Superset").tag(CompoundWorkoutMode.superset)
                Text("Circuit").tag(CompoundWorkoutMode.circuit)
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(mode == .superset
                ? "Alternate between 2 exercises with minimal rest."
                : "Cycle through 3+ exercises in rounds.")
        }
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        Section("Exercises (\(selectedExercises.count))") {
            ForEach(selectedExercises) { exercise in
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(exercise.localizedName)
                            .font(.body)
                        Text(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .onDelete { indexSet in
                selectedExercises.remove(atOffsets: indexSet)
            }
            .onMove { source, destination in
                selectedExercises.move(fromOffsets: source, toOffset: destination)
            }

            Button {
                showingPicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus.circle.fill")
                    .foregroundStyle(DS.Color.activity)
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        Section("Settings") {
            Stepper("Rounds: \(totalRounds)", value: $totalRounds, in: 1...10)
            Stepper("Rest: \(restBetweenExercises)s", value: $restBetweenExercises, in: 0...120, step: 15)
        }
    }

    // MARK: - Start

    private var startButton: some View {
        Section {
            Button {
                let config = CompoundWorkoutConfig(
                    exercises: selectedExercises,
                    mode: mode,
                    totalRounds: totalRounds,
                    restBetweenExercises: restBetweenExercises
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
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}
