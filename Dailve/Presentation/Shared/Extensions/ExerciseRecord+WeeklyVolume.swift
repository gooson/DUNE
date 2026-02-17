import Foundation

/// Shared weekly volume computation for ExerciseRecord collections.
/// Used by MuscleMapSummaryCard, MuscleMapView, and VolumeAnalysisView.
extension Collection where Element: ExerciseRecordVolumeProviding {

    /// Computes weekly muscle volume from records within the last 7 days.
    /// Primary muscles get full set count; secondary muscles get half (minimum 1).
    func weeklyMuscleVolume(
        from date: Date = Date(),
        days: Int = 7
    ) -> [MuscleGroup: Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: date) ?? date
        let recent = self.filter { $0.volumeDate >= cutoff }

        var volume: [MuscleGroup: Int] = [:]
        for record in recent {
            let setCount = record.volumeSetCount
            for muscle in record.volumePrimaryMuscles {
                volume[muscle, default: 0] += setCount
            }
            for muscle in record.volumeSecondaryMuscles {
                volume[muscle, default: 0] += Swift.max(setCount / 2, 1)
            }
        }
        return volume
    }
}

/// Protocol to allow both ExerciseRecord and ExerciseRecordSnapshot to use weeklyMuscleVolume
protocol ExerciseRecordVolumeProviding {
    var volumeDate: Date { get }
    var volumeSetCount: Int { get }
    var volumePrimaryMuscles: [MuscleGroup] { get }
    var volumeSecondaryMuscles: [MuscleGroup] { get }
}

// MARK: - ExerciseRecord Conformance

extension ExerciseRecord: ExerciseRecordVolumeProviding {
    var volumeDate: Date { date }
    var volumeSetCount: Int { completedSets.count }
    var volumePrimaryMuscles: [MuscleGroup] { primaryMuscles }
    var volumeSecondaryMuscles: [MuscleGroup] { secondaryMuscles }
}
