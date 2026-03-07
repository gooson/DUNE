import Foundation
import Testing
@testable import DUNE

private struct MockVisionExerciseGuideLibrary: ExerciseLibraryQuerying {
    var exercisesByID: [String: ExerciseDefinition] = [:]

    func allExercises() -> [ExerciseDefinition] {
        Array(exercisesByID.values)
    }

    func exercise(byID id: String) -> ExerciseDefinition? {
        exercisesByID[id]
    }

    func search(query: String) -> [ExerciseDefinition] {
        []
    }

    func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition] {
        []
    }

    func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition] {
        []
    }

    func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition] {
        []
    }
}

@Suite("VisionExerciseFormGuideViewModel")
@MainActor
struct VisionExerciseFormGuideViewModelTests {
    @Test("loadIfNeeded orders supported guides and selects the first visible guide")
    func loadIfNeededSeedsGuides() {
        let viewModel = VisionExerciseFormGuideViewModel(
            library: MockVisionExerciseGuideLibrary(
                exercisesByID: [
                    "barbell-row": makeExercise(
                        id: "barbell-row",
                        name: "Barbell Row",
                        localizedName: "바벨 로우",
                        aliases: ["Row"]
                    ),
                    "barbell-bench-press": makeExercise(
                        id: "barbell-bench-press",
                        name: "Barbell Bench Press",
                        localizedName: "바벨 벤치프레스",
                        aliases: ["Bench Press", "플랫 벤치"]
                    ),
                ]
            ),
            guideExerciseIDs: ["barbell-bench-press", "barbell-row"]
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.loadState == .ready)
        #expect(viewModel.visibleGuides.map(\.id) == ["barbell-bench-press", "barbell-row"])
        #expect(viewModel.selectedGuide?.id == "barbell-bench-press")
        #expect(viewModel.selectedGuide?.formCueKeys.isEmpty == false)
    }

    @Test("search filters guides by alias and keeps selection in visible results")
    func searchFiltersByAlias() {
        let viewModel = VisionExerciseFormGuideViewModel(
            library: MockVisionExerciseGuideLibrary(
                exercisesByID: [
                    "barbell-bench-press": makeExercise(
                        id: "barbell-bench-press",
                        name: "Barbell Bench Press",
                        localizedName: "바벨 벤치프레스",
                        aliases: ["Bench Press", "플랫 벤치"]
                    ),
                    "barbell-squat": makeExercise(
                        id: "barbell-squat",
                        name: "Barbell Squat",
                        localizedName: "바벨 스쿼트",
                        aliases: ["Squat", "스쿼트"]
                    ),
                ]
            ),
            guideExerciseIDs: ["barbell-bench-press", "barbell-squat"]
        )

        viewModel.loadIfNeeded()
        viewModel.searchText = "플랫"

        #expect(viewModel.visibleGuides.map(\.id) == ["barbell-bench-press"])
        #expect(viewModel.selectedGuide?.id == "barbell-bench-press")
        #expect(viewModel.emptySearchMessage == nil)
    }

    @Test("no-result search keeps prior selection and reports empty-search copy")
    func noResultSearchKeepsSelection() {
        let viewModel = VisionExerciseFormGuideViewModel(
            library: MockVisionExerciseGuideLibrary(
                exercisesByID: [
                    "barbell-bench-press": makeExercise(
                        id: "barbell-bench-press",
                        name: "Barbell Bench Press",
                        localizedName: "바벨 벤치프레스"
                    ),
                    "barbell-row": makeExercise(
                        id: "barbell-row",
                        name: "Barbell Row",
                        localizedName: "바벨 로우"
                    ),
                ]
            ),
            guideExerciseIDs: ["barbell-bench-press", "barbell-row"]
        )

        viewModel.loadIfNeeded()
        viewModel.selectGuide(id: "barbell-row")
        viewModel.searchText = "does-not-exist"

        #expect(viewModel.visibleGuides.isEmpty)
        #expect(viewModel.selectedGuide?.id == "barbell-row")
        #expect(viewModel.emptySearchMessage?.contains("does-not-exist") == true)
    }

    @Test("missing guide metadata falls back to generic description")
    func missingMetadataFallsBackToGenericDescription() {
        let viewModel = VisionExerciseFormGuideViewModel(
            library: MockVisionExerciseGuideLibrary(
                exercisesByID: [
                    "custom-guide": makeExercise(
                        id: "custom-guide",
                        name: "Custom Guide",
                        localizedName: "커스텀 가이드"
                    ),
                ]
            ),
            guideExerciseIDs: ["custom-guide"]
        )

        viewModel.loadIfNeeded()

        #expect(
            viewModel.selectedGuide?.descriptionKey
                == "Refine your setup, brace, and range of motion before adding load."
        )
        #expect(viewModel.selectedGuide?.formCueKeys.isEmpty == true)
    }

    private func makeExercise(
        id: String,
        name: String,
        localizedName: String,
        aliases: [String]? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: localizedName,
            category: .strength,
            inputType: .setsRepsWeight,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            equipment: .barbell,
            metValue: 5.5,
            aliases: aliases,
            difficulty: "intermediate"
        )
    }
}
