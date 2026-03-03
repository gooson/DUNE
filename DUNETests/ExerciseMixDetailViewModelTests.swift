import Foundation
import Testing
@testable import DUNE

private struct MockExerciseLibrary: ExerciseLibraryQuerying {
    var exercisesByID: [String: ExerciseDefinition] = [:]

    func allExercises() -> [ExerciseDefinition] { Array(exercisesByID.values) }
    func exercise(byID id: String) -> ExerciseDefinition? { exercisesByID[id] }
    func search(query: String) -> [ExerciseDefinition] { [] }
    func exercises(forMuscle muscle: MuscleGroup) -> [ExerciseDefinition] { [] }
    func exercises(forCategory category: ExerciseCategory) -> [ExerciseDefinition] { [] }
    func exercises(forEquipment equipment: Equipment) -> [ExerciseDefinition] { [] }
}

@Suite("ExerciseMixDetailViewModel")
@MainActor
struct ExerciseMixDetailViewModelTests {
    private let calendar = Calendar.current

    private func makeDate(_ daysAgo: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    }

    private func makeDefinition(id: String, name: String) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            localizedName: name,
            category: .strength,
            inputType: .setsRepsWeight,
            primaryMuscles: [.chest],
            secondaryMuscles: [],
            equipment: .barbell,
            metValue: 5.5
        )
    }

    @Test("Uses library localized name when exerciseDefinitionID exists")
    func definitionNamePriority() {
        let library = MockExerciseLibrary(exercisesByID: [
            "bench": makeDefinition(id: "bench", name: "Bench Press")
        ])
        let vm = ExerciseMixDetailViewModel(library: library)

        let records = [
            ExerciseRecord(date: makeDate(0), exerciseType: "legacy-name", duration: 1_800, exerciseDefinitionID: "bench"),
            ExerciseRecord(date: makeDate(1), exerciseType: "legacy-name", duration: 1_600, exerciseDefinitionID: "bench"),
        ]

        vm.loadData(from: records)

        #expect(vm.exerciseFrequencies.count == 1)
        #expect(vm.exerciseFrequencies.first?.exerciseName == "Bench Press")
        #expect(vm.exerciseFrequencies.first?.count == 2)
        #expect(vm.frequencyByName["Bench Press"]?.count == 2)
    }

    @Test("Falls back to record type and ignores blank names")
    func fallbackAndBlankFiltering() {
        let vm = ExerciseMixDetailViewModel(library: MockExerciseLibrary())

        let records = [
            ExerciseRecord(date: makeDate(0), exerciseType: "Custom Move", duration: 1_200),
            ExerciseRecord(date: makeDate(1), exerciseType: "  ", duration: 1_200),
        ]

        vm.loadData(from: records)

        #expect(vm.exerciseFrequencies.count == 1)
        #expect(vm.exerciseFrequencies.first?.exerciseName == "Custom Move")
        #expect(vm.frequencyByName["Custom Move"] != nil)
    }
}
