import Foundation

/// Statistics computed from injury history.
struct InjuryStatistics: Sendable {
    /// Total number of injuries ever recorded.
    let totalCount: Int
    /// Currently active injuries.
    let activeCount: Int
    /// Body parts ordered by injury frequency (descending).
    let frequencyByBodyPart: [(bodyPart: BodyPart, count: Int)]
    /// Average recovery days for completed (ended) injuries. Nil if no ended injuries.
    let averageRecoveryDays: Double?
    /// Longest recovery in days. Nil if no ended injuries.
    let longestRecoveryDays: Int?
}

/// Volume comparison between pre-injury, during-injury, and post-injury periods.
struct InjuryVolumeComparison: Sendable, Identifiable {
    let id: UUID  // injury id
    let bodyPart: BodyPart
    let severity: InjurySeverity
    /// Exercise count in the 14 days before injury start.
    let preInjuryCount: Int
    /// Exercise count during injury period.
    let duringInjuryCount: Int
    /// Exercise count in the 14 days after injury end. Nil if still active.
    let postInjuryCount: Int?
}

/// Computes injury statistics. Pure computation, no side effects.
struct InjuryStatisticsService: Sendable {

    func computeStatistics(from injuries: [InjuryInfo]) -> InjuryStatistics {
        let activeCount = injuries.filter(\.isActive).count

        // Frequency by body part
        var partCounts: [BodyPart: Int] = [:]
        for injury in injuries {
            partCounts[injury.bodyPart, default: 0] += 1
        }
        let frequencyByBodyPart = partCounts
            .sorted { $0.value > $1.value }
            .map { (bodyPart: $0.key, count: $0.value) }

        // Recovery stats (only ended injuries)
        let ended = injuries.filter { $0.endDate != nil }
        let recoveryDays = ended.map(\.durationDays)

        let averageRecoveryDays: Double?
        if !recoveryDays.isEmpty {
            let total = recoveryDays.reduce(0, +)
            averageRecoveryDays = Double(total) / Double(recoveryDays.count)
        } else {
            averageRecoveryDays = nil
        }

        let longestRecoveryDays = recoveryDays.max()

        return InjuryStatistics(
            totalCount: injuries.count,
            activeCount: activeCount,
            frequencyByBodyPart: frequencyByBodyPart,
            averageRecoveryDays: averageRecoveryDays,
            longestRecoveryDays: longestRecoveryDays
        )
    }

    /// Compare exercise volume around injury periods.
    /// - Parameters:
    ///   - injuries: Injury records (can be active or ended)
    ///   - exerciseDates: Dates of all exercise records
    ///   - comparisonWindowDays: Days before/after injury to compare (default 14)
    func computeVolumeComparisons(
        injuries: [InjuryInfo],
        exerciseDates: [Date],
        comparisonWindowDays: Int = 14
    ) -> [InjuryVolumeComparison] {
        guard comparisonWindowDays > 0 else { return [] }
        let calendar = Calendar.current
        let sortedDates = exerciseDates.sorted()

        return injuries.compactMap { injury in
            let startDay = calendar.startOfDay(for: injury.startDate)
            guard let preStart = calendar.date(byAdding: .day, value: -comparisonWindowDays, to: startDay) else {
                return nil
            }

            let preCount = sortedDates.filter { date in
                let d = calendar.startOfDay(for: date)
                return d >= preStart && d < startDay
            }.count

            let endDay: Date
            if let end = injury.endDate {
                endDay = calendar.startOfDay(for: end)
            } else {
                endDay = calendar.startOfDay(for: Date())
            }

            let duringCount = sortedDates.filter { date in
                let d = calendar.startOfDay(for: date)
                return d >= startDay && d <= endDay
            }.count

            let postCount: Int?
            if let end = injury.endDate {
                let postEnd = calendar.date(byAdding: .day, value: comparisonWindowDays, to: calendar.startOfDay(for: end))
                    ?? calendar.startOfDay(for: end)
                let afterEnd = calendar.startOfDay(for: end)
                postCount = sortedDates.filter { date in
                    let d = calendar.startOfDay(for: date)
                    return d > afterEnd && d <= postEnd
                }.count
            } else {
                postCount = nil
            }

            return InjuryVolumeComparison(
                id: injury.id,
                bodyPart: injury.bodyPart,
                severity: injury.severity,
                preInjuryCount: preCount,
                duringInjuryCount: duringCount,
                postInjuryCount: postCount
            )
        }
    }
}
