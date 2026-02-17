import Foundation

struct ExerciseLibraryService: ExerciseLibraryQuerying {
    static let shared = ExerciseLibraryService()

    private let exercises: [ExerciseDefinition]
    private let exerciseByID: [String: ExerciseDefinition]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            AppLogger.data.error("Exercise library JSON not found in bundle")
            self.exercises = []
            self.exerciseByID = [:]
            return
        }
        do {
            let decoded = try JSONDecoder().decode([ExerciseDefinition].self, from: data)
            self.exercises = decoded
            self.exerciseByID = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        } catch {
            AppLogger.data.error("Exercise library JSON decode failed: \(error.localizedDescription)")
            self.exercises = []
            self.exerciseByID = [:]
        }
    }

    /// For testing: initialize with an explicit array
    init(exercises: [ExerciseDefinition]) {
        self.exercises = exercises
        self.exerciseByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    func allExercises() -> [ExerciseDefinition] {
        exercises
    }

    func exercise(byID id: String) -> ExerciseDefinition? {
        exerciseByID[id]
    }

    func search(query: String) -> [ExerciseDefinition] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter { exercise in
            exercise.localizedName.localizedCaseInsensitiveContains(query)
                || exercise.name.localizedCaseInsensitiveContains(query)
        }
    }

    func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition] {
        exercises.filter { exercise in
            exercise.primaryMuscles.contains(muscle)
                || exercise.secondaryMuscles.contains(muscle)
        }
    }

    func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition] {
        exercises.filter { $0.category == category }
    }

    func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition] {
        exercises.filter { $0.equipment == equipment }
    }
}
