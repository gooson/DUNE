import Foundation

protocol WorkoutReportGenerating: Sendable {
    func execute(input: GenerateWorkoutReportUseCase.Input) async -> WorkoutReport
}

/// Aggregates exercise records into a structured workout report with statistics and highlights.
struct GenerateWorkoutReportUseCase: WorkoutReportGenerating, Sendable {

    struct Input: Sendable {
        let records: [ExerciseRecordSnapshot]
        let period: WorkoutReport.Period
        let startDate: Date
        let endDate: Date
        /// Previous period stats for comparison (nil if first period).
        let previousPeriodVolume: Double?
        /// Current workout streak in days.
        let workoutStreak: Int
        /// Personal records achieved during this period.
        let newPersonalRecords: Int
        /// Exercise names that were performed for the first time.
        let newExerciseNames: [String]
    }

    private let formatter: WorkoutReportFormatting

    init(formatter: WorkoutReportFormatting) {
        self.formatter = formatter
    }

    func execute(input: Input) async -> WorkoutReport {
        let stats = computeStats(input: input)
        let muscleBreakdown = computeMuscleBreakdown(input.records)
        let highlights = computeHighlights(input: input, stats: stats)

        let reportWithoutSummary = WorkoutReport(
            period: input.period,
            startDate: input.startDate,
            endDate: input.endDate,
            stats: stats,
            muscleBreakdown: muscleBreakdown,
            highlights: highlights,
            formattedSummary: nil
        )

        let summary = await formatter.format(report: reportWithoutSummary)

        return WorkoutReport(
            period: input.period,
            startDate: input.startDate,
            endDate: input.endDate,
            stats: stats,
            muscleBreakdown: muscleBreakdown,
            highlights: highlights,
            formattedSummary: summary
        )
    }

    // MARK: - Stats Computation

    private func computeStats(input: Input) -> WorkoutReport.Stats {
        let records = input.records
        let totalSessions = records.count
        let totalVolume = records.compactMap(\.totalWeight).filter(\.isFinite).reduce(0, +)
        let totalDuration = Int(records.compactMap(\.durationMinutes).reduce(0, +))
        let activeDays = Set(records.map { Calendar.current.startOfDay(for: $0.date) }).count

        // totalWeight is already volume (weight × reps), so use it directly
        let intensities = records.compactMap { record -> Double? in
            guard let weight = record.totalWeight, weight > 0 else { return nil }
            return weight
        }
        let averageIntensity: Double
        if !intensities.isEmpty {
            let maxPossible = intensities.max() ?? 1
            if maxPossible > 0 {
                averageIntensity = (intensities.reduce(0, +) / Double(intensities.count)) / maxPossible
            } else {
                averageIntensity = 0
            }
        } else {
            averageIntensity = 0
        }

        let volumeChange: Double?
        if let previous = input.previousPeriodVolume, previous > 0 {
            let raw = (totalVolume - previous) / previous
            volumeChange = raw.isFinite ? min(10.0, max(-1.0, raw)) : nil
        } else {
            volumeChange = nil
        }

        return WorkoutReport.Stats(
            totalSessions: totalSessions,
            totalVolume: totalVolume,
            totalDuration: totalDuration,
            activeDays: activeDays,
            averageIntensity: min(1.0, averageIntensity),
            volumeChangePercent: volumeChange
        )
    }

    // MARK: - Muscle Breakdown

    private func computeMuscleBreakdown(_ records: [ExerciseRecordSnapshot]) -> [WorkoutReport.MuscleGroupStat] {
        var volumeByMuscle: [MuscleGroup: Double] = [:]
        var sessionsByMuscle: [MuscleGroup: Int] = [:]

        for record in records {
            let volume = record.totalWeight ?? 0
            for muscle in record.primaryMuscles {
                volumeByMuscle[muscle, default: 0] += volume
                sessionsByMuscle[muscle, default: 0] += 1
            }
            for muscle in record.secondaryMuscles {
                volumeByMuscle[muscle, default: 0] += volume * 0.5
                sessionsByMuscle[muscle, default: 0] += 1
            }
        }

        return volumeByMuscle.keys.sorted { volumeByMuscle[$0, default: 0] > volumeByMuscle[$1, default: 0] }
            .map { muscle in
                WorkoutReport.MuscleGroupStat(
                    muscleGroup: muscle,
                    volume: volumeByMuscle[muscle, default: 0],
                    sessions: sessionsByMuscle[muscle, default: 0]
                )
            }
    }

    // MARK: - Highlights

    private func computeHighlights(
        input: Input,
        stats: WorkoutReport.Stats
    ) -> [WorkoutReport.Highlight] {
        var highlights: [WorkoutReport.Highlight] = []

        if input.newPersonalRecords > 0 {
            highlights.append(.init(
                type: .personalRecord,
                description: String(localized: "\(input.newPersonalRecords) new personal records")
            ))
        }

        if input.workoutStreak >= 3 {
            highlights.append(.init(
                type: .streak,
                description: String(localized: "\(input.workoutStreak)-day workout streak")
            ))
        }

        if let change = stats.volumeChangePercent, change > 0.1 {
            highlights.append(.init(
                type: .volumeIncrease,
                description: String(localized: "Volume up \(Int(change * 100))% vs last period")
            ))
        }

        let expectedDays = input.period == .weekly ? 7 : 30
        let consistencyRatio = Double(stats.activeDays) / Double(expectedDays)
        if consistencyRatio >= 0.5 {
            highlights.append(.init(
                type: .consistency,
                description: String(localized: "Trained \(stats.activeDays) of \(expectedDays) days")
            ))
        }

        for name in input.newExerciseNames.prefix(3) {
            highlights.append(.init(
                type: .newExercise,
                description: String(localized: "First time: \(name)")
            ))
        }

        return highlights
    }
}
