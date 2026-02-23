import Foundation
import Observation

/// ViewModel for the Exercise Mix detail view.
@Observable
@MainActor
final class ExerciseMixDetailViewModel {
    var exerciseFrequencies: [ExerciseFrequency] = []
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
            let name = definition?.name ?? record.exerciseType
            guard !name.isEmpty else { return nil }
            return ExerciseFrequencyService.WorkoutEntry(exerciseName: name, date: record.date)
        }

        exerciseFrequencies = ExerciseFrequencyService.analyze(from: entries)
        isLoading = false
    }
}
