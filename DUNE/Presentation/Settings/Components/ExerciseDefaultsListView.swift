import SwiftUI
import SwiftData

/// List of exercises with their configured default weights.
/// Shows exercises that have saved defaults first, then allows searching all exercises.
struct ExerciseDefaultsListView: View {
    @Query(sort: \ExerciseDefaultRecord.lastUsedDate, order: .reverse)
    private var savedDefaults: [ExerciseDefaultRecord]

    @State private var searchText = ""
    /// Correction #68: Dictionary cache for O(1) lookup in ForEach
    @State private var defaultsByExerciseID: [String: ExerciseDefaultRecord] = [:]
    /// Correction #8/#152: Cache sorted exercises to avoid re-sorting every render
    @State private var cachedAllExercises: [ExerciseDefinition] = []

    @Environment(\.appTheme) private var theme

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
        .onAppear {
            rebuildDefaultsIndex()
            if cachedAllExercises.isEmpty {
                cachedAllExercises = library.allExercises().sorted { $0.localizedName < $1.localizedName }
            }
        }
        .onChange(of: savedDefaults.count) {
            rebuildDefaultsIndex()
        }
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
                    exerciseRow(exercise: exercise, record: defaultsByExerciseID[exercise.id])
                }
            }
        }
    }

    private var filteredExercises: [ExerciseDefinition] {
        if searchText.isEmpty {
            return cachedAllExercises
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
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Spacer()

            if record?.isManualOverride == true {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(theme.accentColor)
            }
        }
    }

    // MARK: - Helpers

    /// Rebuild O(1) lookup dictionary from savedDefaults (Correction #68)
    private func rebuildDefaultsIndex() {
        defaultsByExerciseID = Dictionary(
            savedDefaults.map { ($0.exerciseDefinitionID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }
}

#Preview {
    NavigationStack {
        ExerciseDefaultsListView()
    }
}
