import Foundation
import Observation

struct VisionExerciseGuide: Identifiable, Sendable, Hashable {
    let exercise: ExerciseDefinition
    let descriptionKey: String
    let formCueKeys: [String]

    var id: String { exercise.id }

    var searchTokens: [String] {
        [
            exercise.id,
            exercise.name,
            exercise.localizedName,
        ] + (exercise.aliases ?? [])
    }
}

@Observable
@MainActor
final class VisionExerciseFormGuideViewModel {
    enum LoadState: Equatable {
        case idle
        case ready
        case empty(String)
    }

    static let defaultGuideExerciseIDs: [String] = [
        "barbell-bench-press",
        "barbell-squat",
        "conventional-deadlift",
        "overhead-press",
        "pull-up",
        "barbell-row",
    ]

    var loadState: LoadState = .idle
    var searchText: String = "" {
        didSet {
            normalizeSelection()
        }
    }
    var selectedGuideID: String?

    private(set) var guides: [VisionExerciseGuide] = []

    private let library: ExerciseLibraryQuerying
    private let guideExerciseIDs: [String]

    init(
        library: ExerciseLibraryQuerying = ExerciseLibraryService.shared,
        guideExerciseIDs: [String]? = nil
    ) {
        self.library = library
        self.guideExerciseIDs = guideExerciseIDs ?? Self.defaultGuideExerciseIDs
    }

    func loadIfNeeded() {
        guard guides.isEmpty else {
            normalizeSelection()
            return
        }

        guides = guideExerciseIDs.compactMap { id in
            guard let exercise = library.exercise(byID: id) ?? library.representativeExercise(byID: id) else {
                return nil
            }
            return Self.makeGuide(for: exercise)
        }

        guard !guides.isEmpty else {
            loadState = .empty(String(localized: "Exercise guides will appear after the library is loaded."))
            selectedGuideID = nil
            return
        }

        loadState = .ready
        normalizeSelection()
    }

    func selectGuide(id: String) {
        guard guides.contains(where: { $0.id == id }) else { return }
        selectedGuideID = id
    }

    var visibleGuides: [VisionExerciseGuide] {
        let trimmed = searchQuery
        guard !trimmed.isEmpty else { return guides }
        return guides.filter { guide in
            guide.searchTokens.contains { token in
                token.localizedCaseInsensitiveContains(trimmed)
            }
        }
    }

    var selectedGuide: VisionExerciseGuide? {
        if let selectedGuideID,
           let selected = guides.first(where: { $0.id == selectedGuideID }) {
            return selected
        }
        return visibleGuides.first ?? guides.first
    }

    var emptySearchMessage: String? {
        let trimmed = searchQuery
        guard !trimmed.isEmpty, visibleGuides.isEmpty else { return nil }
        return String(localized: "No guides matched \(trimmed).")
    }

    var hasGuides: Bool {
        !guides.isEmpty
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeSelection() {
        guard !guides.isEmpty else {
            selectedGuideID = nil
            return
        }

        let visible = visibleGuides
        if let selectedGuideID {
            if visible.isEmpty || visible.contains(where: { $0.id == selectedGuideID }) {
                return
            }
        }

        selectedGuideID = visible.first?.id ?? guides.first?.id
    }

    private static func makeGuide(for exercise: ExerciseDefinition) -> VisionExerciseGuide {
        let metadataID = metadataLookupID(for: exercise.id)
        let descriptionKey = ExerciseDescriptions.description(for: exercise.id)
            ?? ExerciseDescriptions.description(for: metadataID)
            ?? "Refine your setup, brace, and range of motion before adding load."
        let directCues = ExerciseDescriptions.formCues(for: exercise.id)
        let metadataCues = ExerciseDescriptions.formCues(for: metadataID)

        return VisionExerciseGuide(
            exercise: exercise,
            descriptionKey: descriptionKey,
            formCueKeys: directCues.isEmpty ? metadataCues : directCues
        )
    }

    private static func metadataLookupID(for exerciseID: String) -> String {
        switch exerciseID {
        case "conventional-deadlift":
            "deadlift"
        default:
            exerciseID
        }
    }
}
