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

    @Test("Detail uses the exact merged summary frequencies")
    func mergedSummaryParity() {
        let vm = ExerciseMixDetailViewModel(library: MockExerciseLibrary())
        let summary = ExerciseMixService.analyze([
            .init(id: "manual", linkedWorkoutID: "hk", isHealthKit: false,
                  date: makeDate(0), name: "Bench Press", kind: .strength,
                  primaryMuscles: [.chest], completedSets: 3,
                  durationMinutes: nil, distanceKm: nil),
            .init(id: "hk", linkedWorkoutID: "hk", isHealthKit: true,
                  date: makeDate(0), name: "Bench Press", kind: .strength,
                  primaryMuscles: [], completedSets: 0,
                  durationMinutes: nil, distanceKm: nil)
        ], asOf: Date())

        vm.load(summary: summary)

        #expect(summary.total == 1)
        #expect(vm.exerciseFrequencies == summary.frequencies)
        #expect(vm.frequencyByName["Bench Press"]?.count == 1)
    }
    @Test("Donut selection uses cumulative raw counts and clears out-of-range values")
    func donutSelectionUsesRawCounts() {
        let values = [("First", 3), ("Second", 1), ("Third", 2)].map {
            ExerciseFrequency(exerciseName: $0.0, count: $0.1, lastDate: nil, percentage: 0)
        }
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: nil, frequencies: values) == nil)
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: .nan, frequencies: values) == nil)
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: -0.1, frequencies: values) == nil)
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 0, frequencies: values) == "First")
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 2.9, frequencies: values) == "First")
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 3, frequencies: values) == "Second")
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 3.5, frequencies: values) == "Second")
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 4, frequencies: values) == "Third")
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 6, frequencies: values) == nil)
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 0, frequencies: []) == nil)
        let zero = ExerciseFrequency(exerciseName: "Zero", count: 0, lastDate: nil, percentage: 0)
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 0, frequencies: [zero] + values) == "First")
        let nine = (0..<9).map { ExerciseFrequency(exerciseName: "\($0)", count: 1, lastDate: nil, percentage: 0) }
        let displayed = Array(nine.prefix(8))
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 7.5, frequencies: displayed) == "7")
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 8, frequencies: displayed) == nil)
        #expect(ExerciseMixDetailViewModel.selectedExercise(for: 8.5, frequencies: nine) == "8")
    }

}
