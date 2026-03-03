import Foundation
import Observation

/// ViewModel for the Exercise Mix detail view.
@Observable
@MainActor
final class ExerciseMixDetailViewModel {
    var exerciseFrequencies: [ExerciseFrequency] = []
    var frequencyByName: [String: ExerciseFrequency] = [:]
    var isLoading = false

    private let library: ExerciseLibraryQuerying
    @ObservationIgnored
    private var localizedExerciseNameLookup: [String: String] = [:]

    init(library: ExerciseLibraryQuerying = ExerciseLibraryService.shared) {
        self.library = library
        self.localizedExerciseNameLookup = buildLocalizedExerciseNameLookup()
    }

    /// Computes exercise frequency from all exercise records.
    func loadData(from exerciseRecords: [ExerciseRecord]) {
        isLoading = true

        let entries = exerciseRecords.compactMap { record -> ExerciseFrequencyService.WorkoutEntry? in
            let definition = record.exerciseDefinitionID.flatMap { library.exercise(byID: $0) }
            let name = resolveDisplayName(record: record, definition: definition)
            guard !name.isEmpty else { return nil }
            return ExerciseFrequencyService.WorkoutEntry(exerciseName: name, date: record.date)
        }

        exerciseFrequencies = ExerciseFrequencyService.analyze(from: entries)
        frequencyByName = Dictionary(uniqueKeysWithValues: exerciseFrequencies.map { ($0.exerciseName, $0) })
        isLoading = false
    }

    private func resolveDisplayName(record: ExerciseRecord, definition: ExerciseDefinition?) -> String {
        if let localizedName = definition?.localizedName, !localizedName.isEmpty {
            return localizedName
        }

        let normalizedKey = normalizeExerciseNameLookupKey(record.exerciseType)
        if let localizedName = localizedExerciseNameLookup[normalizedKey], !localizedName.isEmpty {
            return localizedName
        }

        if let mapped = WorkoutActivityType.localizedDisplayName(forStoredTitle: record.exerciseType) {
            return mapped
        }

        if let inferred = WorkoutActivityType.infer(from: record.exerciseType) {
            return inferred.displayName
        }

        return record.exerciseType
    }

    private func buildLocalizedExerciseNameLookup() -> [String: String] {
        var lookup: [String: String] = [:]

        for exercise in library.allExercises() {
            let localizedName = exercise.localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !localizedName.isEmpty else { continue }

            var candidates = [exercise.name, exercise.localizedName]
            if let aliases = exercise.aliases {
                candidates.append(contentsOf: aliases)
            }

            for candidate in candidates {
                let key = normalizeExerciseNameLookupKey(candidate)
                guard !key.isEmpty else { continue }
                lookup[key] = localizedName
            }
        }

        return lookup
    }

    private func normalizeExerciseNameLookupKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }
}
