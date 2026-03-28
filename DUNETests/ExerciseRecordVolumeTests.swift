import Foundation
import Testing
@testable import DUNE

// MARK: - Test stub for WorkoutSetVolumeProviding

private struct StubSet: WorkoutSetVolumeProviding {
    var isVolumeCompleted: Bool
    var volumeWeight: Double
    var volumeReps: Double
}

@Suite("Training Volume Calculation")
struct ExerciseRecordVolumeTests {

    // MARK: - trainingVolume() core calculation

    @Test("trainingVolume computes weight × reps correctly")
    func trainingVolumeWeightTimesReps() {
        // 3 sets: 60kg × 10, 80kg × 8, 100kg × 5
        // Expected: 600 + 640 + 500 = 1740
        let sets: [StubSet] = [
            StubSet(isVolumeCompleted: true, volumeWeight: 60, volumeReps: 10),
            StubSet(isVolumeCompleted: true, volumeWeight: 80, volumeReps: 8),
            StubSet(isVolumeCompleted: true, volumeWeight: 100, volumeReps: 5),
        ]
        #expect(sets.trainingVolume() == 1740)
    }

    @Test("trainingVolume skips incomplete sets")
    func trainingVolumeSkipsIncomplete() {
        let sets: [StubSet] = [
            StubSet(isVolumeCompleted: true, volumeWeight: 60, volumeReps: 10),
            StubSet(isVolumeCompleted: false, volumeWeight: 80, volumeReps: 8),
        ]
        #expect(sets.trainingVolume() == 600) // only the first set
    }

    @Test("trainingVolume returns nil for zero weight")
    func trainingVolumeNilForZeroWeight() {
        // Bodyweight exercises: weight = 0
        let sets: [StubSet] = [
            StubSet(isVolumeCompleted: true, volumeWeight: 0, volumeReps: 20),
        ]
        #expect(sets.trainingVolume() == nil)
    }

    @Test("trainingVolume returns nil for zero reps")
    func trainingVolumeNilForZeroReps() {
        let sets: [StubSet] = [
            StubSet(isVolumeCompleted: true, volumeWeight: 60, volumeReps: 0),
        ]
        #expect(sets.trainingVolume() == nil)
    }

    @Test("trainingVolume returns nil for empty array")
    func trainingVolumeNilForEmpty() {
        let sets: [StubSet] = []
        #expect(sets.trainingVolume() == nil)
    }

    @Test("trainingVolume is capped at maxTrainingVolume")
    func trainingVolumeCapped() {
        let sets: [StubSet] = [
            StubSet(isVolumeCompleted: true, volumeWeight: 500_000, volumeReps: 10),
        ]
        #expect(sets.trainingVolume() == [StubSet].maxTrainingVolume)
    }

    @Test("trainingVolume skips non-finite weight")
    func trainingVolumeSkipsInfinity() {
        let sets: [StubSet] = [
            StubSet(isVolumeCompleted: true, volumeWeight: .infinity, volumeReps: 10),
            StubSet(isVolumeCompleted: true, volumeWeight: 60, volumeReps: 10),
        ]
        #expect(sets.trainingVolume() == 600)
    }

    // MARK: - Weekly volume aggregation

    @Test("Weekly volume sums snapshot totalWeight values")
    func weeklyVolumeSumsCorrectly() {
        let snapshots = [
            ExerciseRecordSnapshot(
                date: Date(),
                primaryMuscles: [.chest],
                secondaryMuscles: [],
                completedSetCount: 3,
                totalWeight: 1800
            ),
            ExerciseRecordSnapshot(
                date: Date(),
                primaryMuscles: [.quadriceps],
                secondaryMuscles: [],
                completedSetCount: 3,
                totalWeight: 2400
            ),
        ]

        let total = snapshots.compactMap(\.totalWeight).reduce(0, +)
        #expect(total == 4200)
    }

    @Test("Weekly volume filters nil totalWeight")
    func weeklyVolumeFiltersNil() {
        let snapshots = [
            ExerciseRecordSnapshot(
                date: Date(),
                primaryMuscles: [.chest],
                secondaryMuscles: [],
                completedSetCount: 3,
                totalWeight: 1800
            ),
            ExerciseRecordSnapshot(
                date: Date(),
                primaryMuscles: [.chest],
                secondaryMuscles: [],
                completedSetCount: 10,
                totalWeight: nil
            ),
        ]

        let total = snapshots.compactMap(\.totalWeight).reduce(0, +)
        #expect(total == 1800)
    }
}
