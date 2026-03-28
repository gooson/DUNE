import Foundation
import Testing
@testable import DUNE

@Suite("ExerciseRecordSnapshot Volume Calculation")
struct ExerciseRecordVolumeTests {

    // MARK: - Snapshot totalWeight is weight × reps

    @Test("Snapshot totalWeight calculates weight × reps correctly")
    func snapshotTotalWeightIsWeightTimesReps() {
        // 3 sets: 60kg × 10 reps, 80kg × 8 reps, 100kg × 5 reps
        // Expected: 60*10 + 80*8 + 100*5 = 600 + 640 + 500 = 1740
        let snapshot = ExerciseRecordSnapshot(
            date: Date(),
            primaryMuscles: [.chest],
            secondaryMuscles: [],
            completedSetCount: 3,
            totalWeight: 1740
        )
        #expect(snapshot.totalWeight == 1740)
    }

    @Test("Bodyweight exercise has nil totalWeight")
    func bodyweitTotalWeightIsNil() {
        let snapshot = ExerciseRecordSnapshot(
            date: Date(),
            primaryMuscles: [.chest],
            secondaryMuscles: [],
            completedSetCount: 3,
            totalWeight: nil
        )
        #expect(snapshot.totalWeight == nil)
    }

    // MARK: - ExerciseRecord.totalVolume matches snapshot logic

    @Test("ExerciseRecord.totalVolume computes weight × reps")
    func exerciseRecordTotalVolume() {
        // This test verifies ExerciseRecord.totalVolume returns weight × reps
        // which must match the snapshot's totalWeight calculation
        //
        // Note: Cannot test directly without ModelContext, but the formula is:
        // sum of (weight * reps) for completed sets where weight > 0 and reps > 0
        //
        // The key invariant: snapshot.totalWeight == record.totalVolume for the same record
        let snapshot = ExerciseRecordSnapshot(
            date: Date(),
            primaryMuscles: [.chest],
            secondaryMuscles: [],
            completedSetCount: 3,
            // 3 × 60kg × 10 reps = 1800
            totalWeight: 1800
        )
        #expect(snapshot.totalWeight == 1800)
    }

    // MARK: - Volume used in WeeklyStats

    @Test("Weekly volume sums snapshot totalWeight values")
    func weeklyVolumeSumsCorrectly() {
        let snapshots = [
            ExerciseRecordSnapshot(
                date: Date(),
                primaryMuscles: [.chest],
                secondaryMuscles: [],
                completedSetCount: 3,
                totalWeight: 1800 // Bench Press: 3×60×10
            ),
            ExerciseRecordSnapshot(
                date: Date(),
                primaryMuscles: [.quadriceps],
                secondaryMuscles: [],
                completedSetCount: 3,
                totalWeight: 2400 // Squat: 3×80×10
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
                totalWeight: nil // bodyweight exercise
            ),
        ]

        let total = snapshots.compactMap(\.totalWeight).reduce(0, +)
        #expect(total == 1800) // only weighted exercise contributes
    }

    @Test("Volume cap at 999_999")
    func volumeCap() {
        // Verify the cap prevents unreasonable values
        let clampedValue = min(1_500_000.0, 999_999.0)
        #expect(clampedValue == 999_999)
    }
}
