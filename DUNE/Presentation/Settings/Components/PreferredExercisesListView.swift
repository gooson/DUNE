import SwiftUI
import SwiftData

/// Dedicated screen for marking preferred exercises that should surface near the top of Quick Start.
struct PreferredExercisesListView: View {
    @Query(sort: \ExerciseDefaultRecord.lastUsedDate, order: .reverse)
    private var savedDefaults: [ExerciseDefaultRecord]

    @State private var searchText = ""
    @State private var defaultsByExerciseID: [String: ExerciseDefaultRecord] = [:]
    @State private var cachedAllExercises: [ExerciseDefinition] = []

    @Environment(\.modelContext) private var modelContext

    private let library = ExerciseLibraryService.shared

    private var savedDefaultsSnapshot: [String] {
        savedDefaults.map { record in
            "\(record.id.uuidString)-\(record.exerciseDefinitionID)-\(record.isPreferred)-\(record.lastUsedDate.timeIntervalSince1970)"
        }
    }

    private var allExercisesSectionTitle: LocalizedStringKey {
        searchText.isEmpty ? "All Exercises" : "Results"
    }

    var body: some View {
        List {
            if searchText.isEmpty, !preferredExercises.isEmpty {
                Section("Preferred") {
                    ForEach(preferredExercises) { exercise in
                        preferredToggleRow(for: exercise)
                    }
                }
            }

            Section(allExercisesSectionTitle) {
                ForEach(filteredExercises) { exercise in
                    preferredToggleRow(for: exercise)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Preferred Exercises")
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

    private var preferredExercises: [ExerciseDefinition] {
        var seen = Set<String>()
        return savedDefaults.compactMap { record in
            guard record.isPreferred else { return nil }
            guard let exercise = library.representativeExercise(byID: record.exerciseDefinitionID) else { return nil }
            return seen.insert(exercise.id).inserted ? exercise : nil
        }
    }

    private var filteredExercises: [ExerciseDefinition] {
        if searchText.isEmpty {
            let preferredIDs = Set(preferredExercises.map(\.id))
            return cachedAllExercises.filter { !preferredIDs.contains($0.id) }
        }
        return library.search(query: searchText)
    }

    private func preferredToggleRow(for exercise: ExerciseDefinition) -> some View {
        Toggle(isOn: preferredBinding(for: exercise)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.localizedName)
                    .font(.body)

                Text(exercise.primaryMuscles.map(\.displayName).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .accessibilityIdentifier("preferred-exercise-toggle-\(exercise.id)")
    }

    private func preferredBinding(for exercise: ExerciseDefinition) -> Binding<Bool> {
        Binding(
            get: { defaultsByExerciseID[exercise.id]?.isPreferred == true },
            set: { newValue in
                setPreferred(newValue, for: exercise)
            }
        )
    }

    private func setPreferred(_ isPreferred: Bool, for exercise: ExerciseDefinition) {
        let now = Date()

        if let record = defaultsByExerciseID[exercise.id] {
            if !isPreferred && record.defaultWeight == nil && record.defaultReps == nil && !record.isManualOverride {
                withAnimation {
                    modelContext.delete(record)
                }
                defaultsByExerciseID.removeValue(forKey: exercise.id)
            } else {
                record.exerciseDefinitionID = exercise.id
                record.isPreferred = isPreferred
                record.lastUsedDate = now
            }
        } else if isPreferred {
            let record = ExerciseDefaultRecord(
                exerciseDefinitionID: exercise.id,
                isPreferred: true,
                lastUsedDate: now
            )
            modelContext.insert(record)
            defaultsByExerciseID[exercise.id] = record
        }

        WatchSessionManager.shared.syncExerciseLibraryToWatch(using: modelContext)
    }

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
        PreferredExercisesListView()
    }
}
