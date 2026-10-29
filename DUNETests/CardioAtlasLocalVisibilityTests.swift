import Foundation
import Testing
@testable import DUNE

@Suite("Cardio Atlas local visibility")
@MainActor
struct CardioAtlasLocalVisibilityTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("A simultaneous Watch workout cannot replace a local record linked to a different missing HK ID")
    func differentLinkedWatchIdentity() {
        let record = localRun(healthKitWorkoutID: "HK-outside-page")
        let watch = workout(id: "HK-other-watch", type: .running, isFromThisApp: true)
        let visible = [watch].localRecordsForDisplay(against: [record])
        #expect(visible.count == 1)
        #expect([watch].filteringAppDuplicates(against: [record]).count == 1)
        let viewModel = ExerciseViewModel()
        viewModel.manualRecords = [record]
        viewModel.healthKitWorkouts = [watch]
        #expect(viewModel.allExercises.count == 2)
    }

    @Test("Raw activity IDs cover cardio types that have no English name keyword")
    func rawActivityIDs() {
        let types: [WorkoutActivityType] = [.mixedCardio, .stepTraining, .highIntensityIntervalTraining, .handCycling]
        let records = types.map { type in
            ExerciseRecord(date: date, exerciseType: "Custom cardio title", duration: 600,
                           exerciseDefinitionID: type.rawValue)
        }
        let visible = [WorkoutSummary]().localRecordsForDisplay(against: records)
        #expect(visible.count == types.count)
    }

    @Test("A saved no-set cardio workout remains reachable without HealthKit")
    func localCardioWithoutHealthKit() {
        let record = localRun()
        let viewModel = ExerciseViewModel()
        viewModel.manualRecords = [record]
        viewModel.healthKitWorkouts = []

        #expect(viewModel.allExercises.count == 1)
        #expect(viewModel.allExercises.first?.source == .manual)
        #expect(viewModel.allExercises.first?.id == record.id.uuidString)
        #expect([WorkoutSummary]().localRecordsForDisplay(against: [record]).count == 1)
    }

    @Test("A linked HealthKit summary keeps its richer row instead of a no-set local duplicate")
    func linkedHealthKitPreferred() {
        let record = localRun(healthKitWorkoutID: "HK-RUN")
        let summary = workout(id: "HK-RUN", type: .running, isFromThisApp: true)
        let viewModel = ExerciseViewModel()
        viewModel.manualRecords = [record]
        viewModel.healthKitWorkouts = [summary]

        #expect(viewModel.allExercises.count == 1)
        #expect(viewModel.allExercises.first?.source == .healthKit)
        #expect(viewModel.allExercises.first?.heartRateAvg == 142)
        #expect([summary].localRecordsForDisplay(against: [record]).isEmpty)
    }

    @Test("App-origin type and date fallback prefers HealthKit when a write lacks a link ID")
    func unlinkedHealthKitPreferred() {
        let record = localRun()
        let summary = workout(id: "HK-RUN", type: .running, isFromThisApp: true)
        let viewModel = ExerciseViewModel()
        viewModel.manualRecords = [record]
        viewModel.healthKitWorkouts = [summary]

        #expect(viewModel.allExercises.count == 1)
        #expect(viewModel.allExercises.first?.source == .healthKit)
        #expect([summary].localRecordsForDisplay(against: [record]).isEmpty)
    }

    @Test("A failed HealthKit write leaves the saved cardio row visible")
    func missingHealthKitWrite() {
        let record = localRun()
        let viewModel = ExerciseViewModel()
        viewModel.manualRecords = [record]

        #expect(viewModel.allExercises.count == 1)
        #expect(viewModel.allExercises.first?.source == .manual)
    }

    @Test("An unrelated Watch workout is retained beside local cardio")
    func unrelatedWatchWorkout() {
        let record = localRun()
        let watch = workout(id: "HK-WATCH", type: .cycling, isFromThisApp: true)
        let viewModel = ExerciseViewModel()
        viewModel.manualRecords = [record]
        viewModel.healthKitWorkouts = [watch]

        #expect(viewModel.allExercises.count == 2)
        #expect(viewModel.allExercises.contains { $0.source == .manual })
        #expect(viewModel.allExercises.contains { $0.source == .healthKit && $0.id == watch.id })
    }

    @Test("Empty and strength stubs do not become cardio fallback rows")
    func emptyAndNonCardioRecordsIgnored() {
        let empty = ExerciseRecord(date: date, exerciseType: "Running", duration: 0)
        let strength = ExerciseRecord(date: date, exerciseType: "Bench Press", duration: 1_200)
        let selected = [WorkoutSummary]().localRecordsForDisplay(against: [empty, strength])
        #expect(selected.isEmpty)
    }

    private func localRun(healthKitWorkoutID: String? = nil) -> ExerciseRecord {
        ExerciseRecord(
            date: date,
            exerciseType: "Atlas Route Run",
            duration: 1_200,
            distance: 2,
            healthKitWorkoutID: healthKitWorkoutID,
            exerciseDefinitionID: "running"
        )
    }

    private func workout(id: String, type: WorkoutActivityType, isFromThisApp: Bool) -> WorkoutSummary {
        WorkoutSummary(
            id: id,
            type: type.rawValue,
            activityType: type,
            duration: 1_200,
            calories: 200,
            distance: 2,
            date: date,
            isFromThisApp: isFromThisApp,
            heartRateAvg: 142
        )
    }
}
