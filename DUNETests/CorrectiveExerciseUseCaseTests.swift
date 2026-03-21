import Foundation
import Testing
@testable import DUNE

private struct MockCorrectiveLibrary: ExerciseLibraryQuerying {
    var exercisesByID: [String: ExerciseDefinition] = [:]

    func allExercises() -> [ExerciseDefinition] { Array(exercisesByID.values) }
    func exercise(byID id: String) -> ExerciseDefinition? { exercisesByID[id] }
    func search(query: String) -> [ExerciseDefinition] { [] }
    func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition] { [] }
    func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition] { [] }
    func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition] { [] }
}

@Suite("CorrectiveExerciseUseCase")
struct CorrectiveExerciseUseCaseTests {

    private func makeExercise(
        id: String,
        name: String = "",
        category: ExerciseCategory = .flexibility,
        equipment: Equipment = .bodyweight
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name.isEmpty ? id : name,
            localizedName: name.isEmpty ? id : name,
            category: category,
            inputType: .durationIntensity,
            primaryMuscles: [.shoulders],
            secondaryMuscles: [],
            equipment: equipment,
            metValue: 3.0,
            aliases: nil,
            difficulty: nil,
            tags: nil,
            description: nil,
            customCategoryName: nil,
            cardioSecondaryUnit: nil
        )
    }

    private func makeMetric(
        type: PostureMetricType,
        status: PostureStatus,
        score: Int = 50
    ) -> PostureMetricResult {
        PostureMetricResult(
            type: type,
            value: 10.0,
            unit: .degrees,
            status: status,
            score: score
        )
    }

    private func makeUseCase(exerciseIDs: [String]) -> CorrectiveExerciseUseCase {
        var exercises: [String: ExerciseDefinition] = [:]
        for id in exerciseIDs {
            exercises[id] = makeExercise(id: id)
        }
        return CorrectiveExerciseUseCase(library: MockCorrectiveLibrary(exercisesByID: exercises))
    }

    // MARK: - Basic

    @Test("All normal metrics returns empty recommendations")
    func allNormal() {
        let useCase = makeUseCase(exerciseIDs: ["stretching"])
        let metrics = [
            makeMetric(type: .forwardHead, status: .normal),
            makeMetric(type: .roundedShoulders, status: .normal),
        ]
        let result = useCase.recommendations(for: metrics)
        #expect(result.isEmpty)
    }

    @Test("Caution metric returns recommendations")
    func cautionMetric() {
        let useCase = makeUseCase(exerciseIDs: ["stretching", "mobility-work", "yoga"])
        let metrics = [makeMetric(type: .forwardHead, status: .caution)]
        let result = useCase.recommendations(for: metrics)
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { $0.targetMetrics.contains(.forwardHead) })
    }

    @Test("Warning metric returns recommendations")
    func warningMetric() {
        let useCase = makeUseCase(exerciseIDs: ["band-pull-apart", "reverse-fly", "face-pull"])
        let metrics = [makeMetric(type: .roundedShoulders, status: .warning)]
        let result = useCase.recommendations(for: metrics)
        #expect(!result.isEmpty)
    }

    @Test("Empty metrics returns empty recommendations")
    func emptyMetrics() {
        let useCase = makeUseCase(exerciseIDs: ["stretching"])
        let result = useCase.recommendations(for: [])
        #expect(result.isEmpty)
    }

    // MARK: - Priority

    @Test("Warning metrics get higher priority than caution")
    func warningPriority() {
        let allIDs = ["stretching", "mobility-work", "yoga",
                      "band-pull-apart", "reverse-fly", "face-pull"]
        let useCase = makeUseCase(exerciseIDs: allIDs)

        let metrics = [
            makeMetric(type: .forwardHead, status: .caution),
            makeMetric(type: .roundedShoulders, status: .warning),
        ]

        let result = useCase.recommendations(for: metrics)
        #expect(!result.isEmpty)

        // First recommendation should be for roundedShoulders (warning)
        if let first = result.first {
            #expect(first.targetMetrics.contains(.roundedShoulders))
        }
    }

    // MARK: - Deduplication

    @Test("Shared exercises deduplicated with merged target metrics")
    func deduplication() {
        // dead-bug is shared by thoracicKyphosis, hipAsymmetry, lateralShift
        let useCase = makeUseCase(exerciseIDs: ["dead-bug", "foam-rolling", "yoga",
                                                 "glute-bridge-unilateral", "plank", "glute-bridge"])
        let metrics = [
            makeMetric(type: .thoracicKyphosis, status: .caution),
            makeMetric(type: .hipAsymmetry, status: .caution),
            makeMetric(type: .lateralShift, status: .caution),
        ]

        let result = useCase.recommendations(for: metrics)

        // dead-bug should appear only once
        let deadBugEntries = result.filter { $0.id == "dead-bug" }
        #expect(deadBugEntries.count == 1)

        // But should have multiple target metrics
        if let deadBug = deadBugEntries.first {
            #expect(deadBug.targetMetrics.count >= 2)
        }
    }

    // MARK: - Missing Exercise IDs

    @Test("Missing exercise IDs gracefully skipped")
    func missingIDs() {
        // Only provide one of three expected exercises
        let useCase = makeUseCase(exerciseIDs: ["stretching"])
        let metrics = [makeMetric(type: .forwardHead, status: .caution)]
        let result = useCase.recommendations(for: metrics)

        #expect(result.count == 1)
        #expect(result.first?.id == "stretching")
    }

    // MARK: - Limit

    @Test("Recommendations capped at limit")
    func limit() {
        let allIDs = ["stretching", "mobility-work", "yoga",
                      "band-pull-apart", "reverse-fly", "face-pull",
                      "foam-rolling", "dead-bug", "bodyweight-squat",
                      "glute-bridge", "plank", "glute-bridge-unilateral"]
        let useCase = makeUseCase(exerciseIDs: allIDs)

        let metrics = PostureMetricType.allCases.map {
            makeMetric(type: $0, status: .warning)
        }

        let result = useCase.recommendations(for: metrics, limit: 8)
        #expect(result.count <= 8)
    }

    // MARK: - Unmeasurable

    @Test("Unmeasurable metrics excluded from recommendations")
    func unmeasurableExcluded() {
        let useCase = makeUseCase(exerciseIDs: ["stretching", "mobility-work", "yoga"])
        let metrics = [makeMetric(type: .forwardHead, status: .unmeasurable)]
        let result = useCase.recommendations(for: metrics)
        #expect(result.isEmpty)
    }

    // MARK: - Static Mapping Coverage

    @Test("All metric types have corrective exercise IDs")
    func allMetricsMapped() {
        for metricType in PostureMetricType.allCases {
            let ids = CorrectiveExerciseUseCase.exerciseIDsByMetric[metricType] ?? []
            #expect(!ids.isEmpty, "No corrective exercises for \(metricType)")
        }
    }
}
