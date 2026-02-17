import Testing
import Foundation
@testable import Dailve

@Suite("ExerciseHistoryViewModel")
struct ExerciseHistoryViewModelTests {

    private func makeRecord(
        id: UUID = UUID(),
        date: Date,
        exerciseDefinitionID: String = "test-exercise",
        sets: [(weight: Double?, reps: Int?)]
    ) -> ExerciseRecord {
        let record = ExerciseRecord(
            date: date,
            exerciseType: "Test Exercise",
            duration: 1800,
            exerciseDefinitionID: exerciseDefinitionID,
            primaryMuscles: [.chest],
            secondaryMuscles: [],
            equipment: .barbell
        )
        record.id = id

        var workoutSets: [WorkoutSet] = []
        for (i, setData) in sets.enumerated() {
            let ws = WorkoutSet(
                setNumber: i + 1,
                setType: .working,
                weight: setData.weight,
                reps: setData.reps,
                isCompleted: true
            )
            ws.exerciseRecord = record
            workoutSets.append(ws)
        }
        record.sets = workoutSets
        return record
    }

    @Test("loadHistory filters by exerciseDefinitionID")
    @MainActor
    func filtersById() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "bench-press", exerciseName: "Bench Press")
        let records = [
            makeRecord(date: .now, exerciseDefinitionID: "bench-press", sets: [(60, 10)]),
            makeRecord(date: .now, exerciseDefinitionID: "squat", sets: [(100, 5)])
        ]
        vm.loadHistory(from: records)
        #expect(vm.sessions.count == 1)
    }

    @Test("sessions sorted chronologically (oldest first)")
    @MainActor
    func sessionsSortedChronologically() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        let older = makeRecord(date: Date(timeIntervalSinceNow: -86400 * 7), sets: [(50, 10)])
        let newer = makeRecord(date: Date(timeIntervalSinceNow: -86400), sets: [(60, 10)])
        vm.loadHistory(from: [newer, older])
        #expect(vm.sessions.count == 2)
        #expect(vm.sessions[0].date < vm.sessions[1].date)
    }

    @Test("maxWeight metric computed correctly")
    @MainActor
    func maxWeight() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        let record = makeRecord(date: .now, sets: [(60, 10), (80, 5), (70, 8)])
        vm.loadHistory(from: [record])
        #expect(vm.sessions.first?.maxWeight == 80)
    }

    @Test("totalVolume computed as sum of weight × reps")
    @MainActor
    func totalVolume() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        // 60×10 + 80×5 + 70×8 = 600 + 400 + 560 = 1560
        let record = makeRecord(date: .now, sets: [(60, 10), (80, 5), (70, 8)])
        vm.loadHistory(from: [record])
        #expect(vm.sessions.first?.totalVolume == 1560)
    }

    @Test("estimatedOneRM uses Epley formula")
    @MainActor
    func estimatedOneRM() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        // Epley: 1RM = weight × (1 + reps / 30)
        // 100kg × (1 + 5/30) = 100 × 1.1667 ≈ 116.67
        let record = makeRecord(date: .now, sets: [(100, 5)])
        vm.loadHistory(from: [record])
        let oneRM = vm.sessions.first?.estimatedOneRM ?? 0
        #expect(abs(oneRM - 116.67) < 0.1)
    }

    @Test("personalBest tracks max value for selected metric")
    @MainActor
    func personalBest() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        let records = [
            makeRecord(date: Date(timeIntervalSinceNow: -86400 * 3), sets: [(60, 10)]),
            makeRecord(date: Date(timeIntervalSinceNow: -86400), sets: [(80, 8)])
        ]
        vm.loadHistory(from: records)
        vm.selectedMetric = .maxWeight
        #expect(vm.personalBest == 80)
    }

    @Test("chartData has correct count")
    @MainActor
    func chartDataCount() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        let records = [
            makeRecord(date: Date(timeIntervalSinceNow: -86400 * 3), sets: [(60, 10)]),
            makeRecord(date: Date(timeIntervalSinceNow: -86400), sets: [(80, 8)])
        ]
        vm.loadHistory(from: records)
        #expect(vm.chartData.count == 2)
    }

    @Test("trendLine computed for 2+ data points")
    @MainActor
    func trendLine() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        let records = [
            makeRecord(date: Date(timeIntervalSinceNow: -86400 * 3), sets: [(60, 10)]),
            makeRecord(date: Date(timeIntervalSinceNow: -86400), sets: [(80, 8)])
        ]
        vm.loadHistory(from: records)
        #expect(vm.trendLine.count == 2)
    }

    @Test("trendLine empty for single data point")
    @MainActor
    func trendLineSinglePoint() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        let records = [makeRecord(date: .now, sets: [(60, 10)])]
        vm.loadHistory(from: records)
        #expect(vm.trendLine.isEmpty)
    }

    @Test("empty records produce no sessions")
    @MainActor
    func emptyRecords() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        vm.loadHistory(from: [])
        #expect(vm.sessions.isEmpty)
        #expect(vm.chartData.isEmpty)
        #expect(vm.personalBest == nil)
    }

    @Test("selectedMetric change updates chartData")
    @MainActor
    func metricChange() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        let records = [makeRecord(date: .now, sets: [(60, 10)])]
        vm.loadHistory(from: records)

        vm.selectedMetric = .maxWeight
        let weightValue = vm.chartData.first?.value
        #expect(weightValue == 60)

        vm.selectedMetric = .totalReps
        let repsValue = vm.chartData.first?.value
        #expect(repsValue == 10)
    }

    @Test("sets with nil weight excluded from volume")
    @MainActor
    func nilWeightExcluded() {
        let vm = ExerciseHistoryViewModel(exerciseDefinitionID: "test-exercise", exerciseName: "Test")
        // Only (60, 10) contributes to volume; (nil, 15) does not
        let record = makeRecord(date: .now, sets: [(60, 10), (nil, 15)])
        vm.loadHistory(from: [record])
        #expect(vm.sessions.first?.totalVolume == 600) // 60 × 10
    }
}
