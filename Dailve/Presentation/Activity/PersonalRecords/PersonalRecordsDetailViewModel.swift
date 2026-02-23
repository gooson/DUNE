import Foundation
import Observation

/// ViewModel for the Personal Records detail view.
@Observable
@MainActor
final class PersonalRecordsDetailViewModel {
    var personalRecords: [StrengthPersonalRecord] = []
    var isLoading = false

    private let library: ExerciseLibraryQuerying

    init(library: ExerciseLibraryQuerying = ExerciseLibraryService.shared) {
        self.library = library
    }

    /// Recomputes PRs from exercise records.
    func loadRecords(from exerciseRecords: [ExerciseRecord]) {
        isLoading = true
        let entries = exerciseRecords.compactMap { record -> StrengthPRService.WorkoutEntry? in
            let definition = record.exerciseDefinitionID.flatMap { library.exercise(byID: $0) }
            let name = definition?.name ?? record.exerciseType
            guard !name.isEmpty else { return nil }

            let completedSets = record.completedSets
            guard completedSets.count > 0 else { return nil }

            let totalWeight = completedSets.compactMap(\.weight).reduce(0, +)
            guard totalWeight > 0 else { return nil }

            return StrengthPRService.WorkoutEntry(
                exerciseName: name,
                date: record.date,
                bestWeight: totalWeight / Double(completedSets.count)
            )
        }
        personalRecords = StrengthPRService.extractPRs(from: entries)
        isLoading = false
    }
}
