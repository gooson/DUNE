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
    private var savedDefaultsSnapshot: [String] {
        savedDefaults.map { record in
            let weight = record.defaultWeight?.description ?? "nil"
            let reps = record.defaultReps.map(String.init) ?? "nil"
            return "\(record.id.uuidString)-\(record.exerciseDefinitionID)-\(weight)-\(reps)-\(record.isManualOverride)-\(record.isPreferred)-\(record.lastUsedDate.timeIntervalSince1970)"
        }
    }

    private var allExercisesSectionTitle: LocalizedStringKey {
        searchText.isEmpty ? "All Exercises" : "Results"
    }

    var body: some View {
        List {
            if searchText.isEmpty {
                savedDefaultsSection
            }
            allExercisesSection
        }
        .accessibilityIdentifier("exercise-defaults-screen")
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Exercise Defaults")
        .searchable(text: $searchText, prompt: "Search exercises")
        .onAppear {
            rebuildDefaultsIndex()
            if cachedAllExercises.isEmpty {
                cachedAllExercises = library.allExercises().sorted { $0.localizedName < $1.localizedName }
            }
        }
        .onChange(of: savedDefaultsSnapshot) {
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
                        .accessibilityIdentifier("exercise-defaults-row-\(exercise.id)")
                    }
                }
            }
            .accessibilityIdentifier("exercise-defaults-configured-section")
        }
    }

    // MARK: - All Exercises

    private var allExercisesSection: some View {
        Section(allExercisesSectionTitle) {
            ForEach(filteredExercises) { exercise in
                NavigationLink {
                    ExerciseDefaultEditView(exercise: exercise)
                } label: {
                    exerciseRow(exercise: exercise, record: defaultsByExerciseID[exercise.id])
                }
                .accessibilityIdentifier("exercise-defaults-row-\(exercise.id)")
            }
        }
        .accessibilityIdentifier("exercise-defaults-all-section")
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
                } else if record?.isPreferred == true {
                    Text("Preferred")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if record?.isPreferred == true {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(DS.Color.positive)
                }

                if record?.isManualOverride == true {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(theme.accentColor)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exercise-defaults-row-\(exercise.id)")
    }

    // MARK: - Helpers

    /// Rebuild O(1) lookup dictionary from savedDefaults (Correction #68)
    private func rebuildDefaultsIndex() {
        defaultsByExerciseID = Dictionary(
            savedDefaults.map { record in
                let representativeID = library.representativeExercise(byID: record.exerciseDefinitionID)?.id
                    ?? record.exerciseDefinitionID
                return (representativeID, record)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

#Preview {
    NavigationStack {
        ExerciseDefaultsListView()
    }
}
