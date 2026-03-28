import Foundation

struct ExerciseLibraryService: ExerciseLibraryQuerying {
    static let shared = ExerciseLibraryService()

    private struct CanonicalIndex {
        let visibleExercises: [ExerciseDefinition]
        let representativeByCanonicalKey: [String: ExerciseDefinition]
    }

    private let exercises: [ExerciseDefinition]
    private let exerciseByID: [String: ExerciseDefinition]
    private let visibleExercises: [ExerciseDefinition]
    private let representativeByCanonicalKey: [String: ExerciseDefinition]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            AppLogger.data.error("Exercise library JSON not found in bundle")
            self.exercises = []
            self.exerciseByID = [:]
            self.visibleExercises = []
            self.representativeByCanonicalKey = [:]
            return
        }
        do {
            let decoded = try JSONDecoder().decode([ExerciseDefinition].self, from: data)
            let canonicalIndex = Self.buildCanonicalIndex(from: decoded)
            self.exercises = decoded
            self.exerciseByID = Dictionary(decoded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            self.visibleExercises = canonicalIndex.visibleExercises
            self.representativeByCanonicalKey = canonicalIndex.representativeByCanonicalKey
        } catch {
            AppLogger.data.error("Exercise library JSON decode failed: \(error.localizedDescription)")
            self.exercises = []
            self.exerciseByID = [:]
            self.visibleExercises = []
            self.representativeByCanonicalKey = [:]
        }
    }

    /// For testing: initialize with an explicit array
    init(exercises: [ExerciseDefinition]) {
        let canonicalIndex = Self.buildCanonicalIndex(from: exercises)
        self.exercises = exercises
        self.exerciseByID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.visibleExercises = canonicalIndex.visibleExercises
        self.representativeByCanonicalKey = canonicalIndex.representativeByCanonicalKey
    }

    func allExercises() -> [ExerciseDefinition] {
        visibleExercises
    }

    func exercise(byID id: String) -> ExerciseDefinition? {
        if let direct = exerciseByID[id] { return direct }
        // Fallback: resolve removed variant ID to canonical base
        let resolved = Self.resolvedExerciseID(for: id)
        return resolved != id ? exerciseByID[resolved] : nil
    }

    func search(query: String) -> [ExerciseDefinition] {
        guard !query.isEmpty else { return visibleExercises }

        var seenCanonicalKeys = Set<String>()
        var results: [ExerciseDefinition] = []

        for exercise in exercises where Self.matchesSearchQuery(query, exercise: exercise) {
            let canonicalKey = Self.canonicalKey(for: exercise)
            guard seenCanonicalKeys.insert(canonicalKey).inserted else { continue }
            results.append(representativeByCanonicalKey[canonicalKey] ?? exercise)
        }

        return results
    }

    func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition] {
        visibleExercises.filter { exercise in
            exercise.primaryMuscles.contains(muscle)
                || exercise.secondaryMuscles.contains(muscle)
        }
    }

    func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition] {
        visibleExercises.filter { $0.category == category }
    }

    func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition] {
        visibleExercises.filter { $0.equipment == equipment }
    }

    private static func buildCanonicalIndex(from exercises: [ExerciseDefinition]) -> CanonicalIndex {
        var representativeByCanonicalKey: [String: ExerciseDefinition] = [:]

        for exercise in exercises {
            let canonicalKey = canonicalKey(for: exercise)
            guard let existing = representativeByCanonicalKey[canonicalKey] else {
                representativeByCanonicalKey[canonicalKey] = exercise
                continue
            }

            if shouldPreferRepresentative(exercise, over: existing, canonicalKey: canonicalKey) {
                representativeByCanonicalKey[canonicalKey] = exercise
            }
        }

        var emittedCanonicalKeys = Set<String>()
        let visibleExercises = exercises.filter { exercise in
            let canonicalKey = canonicalKey(for: exercise)
            guard representativeByCanonicalKey[canonicalKey]?.id == exercise.id else { return false }
            return emittedCanonicalKeys.insert(canonicalKey).inserted
        }

        return CanonicalIndex(
            visibleExercises: visibleExercises,
            representativeByCanonicalKey: representativeByCanonicalKey
        )
    }

    private static func canonicalKey(for exercise: ExerciseDefinition) -> String {
        QuickStartCanonicalService.canonicalKey(
            exerciseID: exercise.id,
            exerciseName: exercise.localizedName
        ) ?? exercise.id
    }

    private static func shouldPreferRepresentative(
        _ candidate: ExerciseDefinition,
        over existing: ExerciseDefinition,
        canonicalKey: String
    ) -> Bool {
        representativeSortKey(for: candidate, canonicalKey: canonicalKey)
            < representativeSortKey(for: existing, canonicalKey: canonicalKey)
    }

    private static func representativeSortKey(
        for exercise: ExerciseDefinition,
        canonicalKey: String
    ) -> (Int, Int, Int, String) {
        (
            exercise.id == canonicalKey ? 0 : 1,
            exercise.id.count,
            exercise.localizedName.count,
            exercise.id
        )
    }

    private static func matchesSearchQuery(_ query: String, exercise: ExerciseDefinition) -> Bool {
        exercise.localizedName.localizedCaseInsensitiveContains(query)
            || exercise.name.localizedCaseInsensitiveContains(query)
            || (exercise.aliases ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

// MARK: - Legacy Variant ID Resolution

extension ExerciseLibraryService {
    /// Explicit remaps for standalone exercises that were merged into different-named bases.
    /// Suffix-based variants (e.g. "push-up-tempo" → "push-up") are handled dynamically
    /// by `QuickStartCanonicalService.canonicalExerciseID(for:)`.
    private static let standaloneMerges: [String: String] = [
        "single-leg-press-machine": "leg-press",
        "single-leg-extension-machine": "leg-extension",
        "single-leg-curl-machine": "leg-curl",
        "single-arm-shoulder-press-machine": "shoulder-press-machine",
    ]

    /// Resolves a potentially removed variant ID to its canonical base ID.
    /// Handles both suffix-based variants and explicit standalone merges.
    /// Returns the input unchanged if it is already a base exercise ID.
    static func resolvedExerciseID(for id: String) -> String {
        // 1. Check explicit standalone merges
        if let merged = standaloneMerges[id] { return merged }
        // 2. Use canonical suffix stripping
        let canonical = QuickStartCanonicalService.canonicalExerciseID(for: id)
        return canonical.isEmpty ? id : canonical
    }
}
