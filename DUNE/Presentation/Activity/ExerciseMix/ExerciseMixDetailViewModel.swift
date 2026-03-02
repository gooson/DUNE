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

    init(library: ExerciseLibraryQuerying = ExerciseLibraryService.shared) {
        self.library = library
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

        if let mapped = WorkoutActivityType.localizedDisplayName(forStoredTitle: record.exerciseType) {
            return mapped
        }

        if let inferred = WorkoutActivityType.infer(from: record.exerciseType) {
            return inferred.displayName
        }

        return record.exerciseType
    }
}
