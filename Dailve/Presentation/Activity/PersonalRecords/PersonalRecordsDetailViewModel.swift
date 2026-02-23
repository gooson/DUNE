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

            let weights = record.completedSets.compactMap(\.weight).filter { $0 > 0 }
            guard !weights.isEmpty else { return nil }

            let avgWeight = weights.reduce(0, +) / Double(weights.count)
            guard avgWeight > 0, avgWeight <= 500 else { return nil }

            return StrengthPRService.WorkoutEntry(
                exerciseName: name,
                date: record.date,
                bestWeight: avgWeight
            )
        }
        personalRecords = StrengthPRService.extractPRs(from: entries)
        isLoading = false
    }
}
