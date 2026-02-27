import Foundation

// MARK: - Training Volume Analysis Service

/// Aggregates workout data from HealthKit and manual records into per-type, per-period summaries.
/// Pure Domain logic — no SwiftUI or HealthKit imports.
enum TrainingVolumeAnalysisService {

    // MARK: - Public API

    /// Analyze training volume for the given period, producing current vs previous comparison.
    static func analyze(
        workouts: [WorkoutSummary],
        manualRecords: [ManualExerciseSnapshot],
        period: VolumePeriod
    ) -> PeriodComparison {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = period.days

        guard let currentStart = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let previousStart = calendar.date(byAdding: .day, value: -(days * 2 - 1), to: today),
              let previousEnd = calendar.date(byAdding: .day, value: -1, to: currentStart)
        else {
            return PeriodComparison(
                current: emptySummary(period: period, start: today, end: today),
                previous: nil
            )
        }

        let currentEnd = Date()

        let currentSummary = buildSummary(
            workouts: workouts.filter { $0.date >= currentStart && $0.date <= currentEnd },
            manualRecords: manualRecords.filter { $0.date >= currentStart && $0.date <= currentEnd },
            period: period,
            start: currentStart,
            end: currentEnd
        )

        let previousSummary = buildSummary(
            workouts: workouts.filter { $0.date >= previousStart && $0.date <= previousEnd },
            manualRecords: manualRecords.filter { $0.date >= previousStart && $0.date <= previousEnd },
            period: period,
            start: previousStart,
            end: previousEnd
        )

        return PeriodComparison(current: currentSummary, previous: previousSummary)
    }

    // MARK: - Build Summary

    private static func buildSummary(
        workouts: [WorkoutSummary],
        manualRecords: [ManualExerciseSnapshot],
        period: VolumePeriod,
        start: Date,
        end: Date
    ) -> VolumePeriodSummary {
        let calendar = Calendar.current
        var typeAggregates: [String: TypeAggregate] = [:]
        var activeDaySet = Set<Date>()

        // Aggregate HealthKit workouts
        for workout in workouts {
            guard workout.duration > 0, workout.duration.isFinite else { continue }
            let key = workout.activityType.rawValue
            var agg = typeAggregates[key] ?? TypeAggregate(
                typeKey: key,
                typeName: workout.activityType.typeName,
                categoryRawValue: workout.activityType.category.rawValue,
                equipmentRawValue: nil,
                isDistanceBased: workout.activityType.isDistanceBased
            )
            agg.totalDuration += workout.duration
            agg.totalCalories += workout.calories ?? 0
            agg.sessionCount += 1
            if workout.activityType.isDistanceBased, let d = workout.distance, d > 0, d.isFinite, d < 500_000 {
                agg.totalDistance += d
            }
            typeAggregates[key] = agg
            activeDaySet.insert(calendar.startOfDay(for: workout.date))
        }

        // Aggregate manual records
        for record in manualRecords {
            guard record.duration > 0, record.duration.isFinite else { continue }
            let key = "manual-\(record.exerciseType)"
            var agg = typeAggregates[key] ?? TypeAggregate(
                typeKey: key,
                typeName: record.exerciseType,
                categoryRawValue: record.categoryRawValue,
                equipmentRawValue: record.equipmentRawValue,
                isDistanceBased: false
            )
            agg.totalDuration += record.duration
            agg.totalCalories += record.calories
            agg.sessionCount += 1
            agg.totalVolume += record.totalVolume
            typeAggregates[key] = agg
            activeDaySet.insert(calendar.startOfDay(for: record.date))
        }

        // Build type volumes with fractions
        let grandTotalDuration = typeAggregates.values.reduce(0.0) { $0 + $1.totalDuration }
        let grandTotalCalories = typeAggregates.values.reduce(0.0) { $0 + $1.totalCalories }

        var exerciseTypes: [ExerciseTypeVolume] = typeAggregates.values.map { agg in
            var vol = ExerciseTypeVolume(
                typeKey: agg.typeKey,
                displayName: agg.typeName,
                categoryRawValue: agg.categoryRawValue,
                equipmentRawValue: agg.equipmentRawValue,
                totalDuration: agg.totalDuration,
                totalCalories: agg.totalCalories,
                sessionCount: agg.sessionCount,
                totalDistance: agg.totalDistance > 0 ? agg.totalDistance : nil,
                totalVolume: agg.totalVolume > 0 ? agg.totalVolume : nil
            )
            if grandTotalDuration > 0 {
                vol.durationFraction = agg.totalDuration / grandTotalDuration
            }
            if grandTotalCalories > 0 {
                vol.calorieFraction = agg.totalCalories / grandTotalCalories
            }
            return vol
        }
        exerciseTypes.sort { $0.totalDuration > $1.totalDuration }

        // Build daily breakdown
        let dailyBreakdown = buildDailyBreakdown(
            workouts: workouts,
            manualRecords: manualRecords,
            start: start,
            end: end
        )

        return VolumePeriodSummary(
            period: period,
            startDate: start,
            endDate: end,
            totalDuration: grandTotalDuration,
            totalCalories: grandTotalCalories,
            totalSessions: typeAggregates.values.reduce(0) { $0 + $1.sessionCount },
            activeDays: activeDaySet.count,
            exerciseTypes: exerciseTypes,
            dailyBreakdown: dailyBreakdown
        )
    }

    // MARK: - Daily Breakdown

    private static func buildDailyBreakdown(
        workouts: [WorkoutSummary],
        manualRecords: [ManualExerciseSnapshot],
        start: Date,
        end: Date
    ) -> [DailyVolumePoint] {
        let calendar = Calendar.current
        var dailySegments: [Date: [String: TimeInterval]] = [:]

        for workout in workouts {
            guard workout.duration > 0, workout.duration.isFinite else { continue }
            let day = calendar.startOfDay(for: workout.date)
            dailySegments[day, default: [:]][workout.activityType.rawValue, default: 0] += workout.duration
        }

        for record in manualRecords {
            guard record.duration > 0, record.duration.isFinite else { continue }
            let day = calendar.startOfDay(for: record.date)
            dailySegments[day, default: [:]][
                "manual-\(record.exerciseType)", default: 0
            ] += record.duration
        }

        // Fill all days in range
        var result: [DailyVolumePoint] = []
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        var current = startDay
        while current <= endDay {
            let segments = dailySegments[current]?.map {
                DailyVolumePoint.Segment(typeKey: $0.key, duration: $0.value)
            }
            .sorted { $0.duration > $1.duration } ?? []
            result.append(DailyVolumePoint(date: current, segments: segments))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    // MARK: - Helpers

    private static func emptySummary(
        period: VolumePeriod,
        start: Date,
        end: Date
    ) -> VolumePeriodSummary {
        VolumePeriodSummary(
            period: period,
            startDate: start,
            endDate: end,
            totalDuration: 0,
            totalCalories: 0,
            totalSessions: 0,
            activeDays: 0,
            exerciseTypes: [],
            dailyBreakdown: []
        )
    }
}

// MARK: - Internal Aggregate

private struct TypeAggregate {
    let typeKey: String
    let typeName: String
    let categoryRawValue: String
    let equipmentRawValue: String?
    let isDistanceBased: Bool
    var totalDuration: TimeInterval = 0
    var totalCalories: Double = 0
    var sessionCount: Int = 0
    var totalDistance: Double = 0
    var totalVolume: Double = 0
}

// MARK: - Manual Exercise Snapshot

/// Lightweight snapshot of an ExerciseRecord for volume analysis.
/// Avoids SwiftData dependency in Domain layer.
struct ManualExerciseSnapshot: Sendable {
    let date: Date
    let exerciseType: String
    let categoryRawValue: String
    let equipmentRawValue: String?
    let duration: TimeInterval
    let calories: Double
    let totalVolume: Double // weight × reps sum
}
