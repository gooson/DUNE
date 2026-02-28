import SwiftUI
import SwiftData

/// List of exercises with their configured default weights.
/// Shows exercises that have saved defaults first, then allows searching all exercises.
struct ExerciseDefaultsListView: View {
    @Query(sort: \ExerciseDefaultRecord.lastUsedDate, order: .reverse)
    private var savedDefaults: [ExerciseDefaultRecord]

    @State private var searchText = ""

    private let library = ExerciseLibraryService.shared

    var body: some View {
        List {
            if searchText.isEmpty {
                savedDefaultsSection
            }
            allExercisesSection
        }
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .navigationTitle("Exercise Defaults")
        .searchable(text: $searchText, prompt: "Search exercises")
    }

    // MARK: - Saved Defaults

    @ViewBuilder
    private var savedDefaultsSection: some View {
        if !savedDefaults.isEmpty {
            Section("Configured") {
                ForEach(savedDefaults) { record in
                    if let exercise = library.exercise(byID: record.exerciseDefinitionID) {
                        NavigationLink {
                            ExerciseDefaultEditView(exercise: exercise)
                        } label: {
                            exerciseRow(exercise: exercise, record: record)
                        }
                    }
                }
            }
        }
    }

    // MARK: - All Exercises

    private var allExercisesSection: some View {
        Section(searchText.isEmpty ? "All Exercises" : "Results") {
            ForEach(filteredExercises) { exercise in
                NavigationLink {
                    ExerciseDefaultEditView(exercise: exercise)
                } label: {
                    exerciseRow(exercise: exercise, record: defaultRecord(for: exercise.id))
                }
            }
        }
    }

    private var filteredExercises: [ExerciseDefinition] {
        if searchText.isEmpty {
            return library.allExercises().sorted { $0.localizedName < $1.localizedName }
        }
        return library.search(query: searchText)
    }

    // MARK: - Row

    private func exerciseRow(exercise: ExerciseDefinition, record: ExerciseDefaultRecord?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.localizedName)
                    .font(.body)

                if let weight = record?.defaultWeight {
                    Text("\(weight.formatted(.number.precision(.fractionLength(0...1)))) kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if record?.isManualOverride == true {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(DS.Color.warmGlow)
            }
        }
    }

    // MARK: - Helpers

    /// Build a lookup from savedDefaults (Correction #68: avoid O(N) in ForEach)
    private func defaultRecord(for exerciseID: String) -> ExerciseDefaultRecord? {
        savedDefaults.first { $0.exerciseDefinitionID == exerciseID }
    }
}

#Preview {
    NavigationStack {
        ExerciseDefaultsListView()
    }
}
