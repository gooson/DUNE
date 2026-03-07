import Foundation

struct WorkoutTemplateRecommendation: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let sequenceTypes: [WorkoutActivityType]
    let sequenceLabels: [String]
    let frequency: Int
    let averageDurationMinutes: Double
    let lastPerformedAt: Date
    let score: Double
}

protocol WorkoutTemplateRecommending: Sendable {
    func recommendTemplates(
        from workouts: [WorkoutSummary],
        config: WorkoutTemplateRecommendationService.Configuration,
        referenceDate: Date
    ) -> [WorkoutTemplateRecommendation]
}

struct WorkoutTemplateRecommendationService: WorkoutTemplateRecommending {
    struct Configuration: Sendable, Equatable {
        var lookbackDays: Int = 42
        var targetWindowMinutes: Double = 30
        var maxSessionGapMinutes: Double = 10
        var minimumFrequency: Int = 3
        var maxRecommendations: Int = 3

        static let `default` = Configuration()
    }

    private struct Session: Sendable {
        let workouts: [WorkoutSummary]
        let startDate: Date
        let endDate: Date

        var durationMinutes: Double {
            max(0, endDate.timeIntervalSince(startDate) / 60.0)
        }

        var key: String {
            workouts.map { $0.activityType.rawValue }.joined(separator: ">")
        }

        var labels: [String] {
            workouts.map(\.type)
        }

        var activityTypes: [WorkoutActivityType] {
            workouts.map(\.activityType)
        }
    }

    private struct Aggregate: Sendable {
        let key: String
        var sessions: [Session]

        var frequency: Int { sessions.count }
        var lastPerformedAt: Date { sessions.map(\.startDate).max() ?? .distantPast }
        var averageDurationMinutes: Double {
            guard !sessions.isEmpty else { return 0 }
            return sessions.reduce(0) { $0 + $1.durationMinutes } / Double(sessions.count)
        }

        var representative: Session? { sessions.max { $0.startDate < $1.startDate } }
    }

    func recommendTemplates(
        from workouts: [WorkoutSummary],
        config: Configuration = .default,
        referenceDate: Date = Date()
    ) -> [WorkoutTemplateRecommendation] {
        guard !workouts.isEmpty,
              config.lookbackDays > 0,
              config.targetWindowMinutes > 0,
              config.maxSessionGapMinutes >= 0,
              config.minimumFrequency > 0,
              config.maxRecommendations > 0 else {
            return []
        }

        let lookbackStart = referenceDate.addingTimeInterval(-Double(config.lookbackDays) * 86_400)
        let filtered = workouts
            .filter { $0.date >= lookbackStart && $0.date <= referenceDate }
            .sorted { $0.date < $1.date }

        let sessions = buildSessions(from: filtered, maxGapMinutes: config.maxSessionGapMinutes)
            .filter { $0.durationMinutes <= config.targetWindowMinutes }
            .filter { !$0.workouts.isEmpty }

        guard !sessions.isEmpty else { return [] }

        var aggregates: [String: Aggregate] = [:]
        for session in sessions {
            aggregates[session.key, default: Aggregate(key: session.key, sessions: [])].sessions.append(session)
        }

        let scored: [WorkoutTemplateRecommendation] = aggregates.values
            .filter { $0.frequency >= config.minimumFrequency }
            .compactMap { aggregate in
                guard let representative = aggregate.representative else { return nil }
                let frequencyScore = min(Double(aggregate.frequency) / Double(config.minimumFrequency), 2.0)
                let daysSince = max(0, referenceDate.timeIntervalSince(aggregate.lastPerformedAt) / 86_400)
                let recencyScore = max(0, 1.0 - (daysSince / Double(config.lookbackDays)))
                let completionRate = min(max(aggregate.averageDurationMinutes / config.targetWindowMinutes, 0), 1)
                let totalScore = (0.5 * frequencyScore) + (0.3 * recencyScore) + (0.2 * completionRate)

                return WorkoutTemplateRecommendation(
                    id: aggregate.key,
                    title: title(for: representative, averageDurationMinutes: aggregate.averageDurationMinutes),
                    sequenceTypes: representative.activityTypes,
                    sequenceLabels: representative.labels,
                    frequency: aggregate.frequency,
                    averageDurationMinutes: aggregate.averageDurationMinutes,
                    lastPerformedAt: aggregate.lastPerformedAt,
                    score: totalScore
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                if lhs.frequency != rhs.frequency {
                    return lhs.frequency > rhs.frequency
                }
                return lhs.lastPerformedAt > rhs.lastPerformedAt
            }

        return Array(scored.prefix(config.maxRecommendations))
    }

    private func buildSessions(from workouts: [WorkoutSummary], maxGapMinutes: Double) -> [Session] {
        guard let first = workouts.first else { return [] }

        let maxGapSeconds = maxGapMinutes * 60
        var sessions: [Session] = []
        var current: [WorkoutSummary] = [first]
        var currentStart = first.date
        var currentEnd = first.date.addingTimeInterval(max(0, first.duration))

        for workout in workouts.dropFirst() {
            let workoutStart = workout.date
            let workoutEnd = workout.date.addingTimeInterval(max(0, workout.duration))
            let gap = workoutStart.timeIntervalSince(currentEnd)

            if gap <= maxGapSeconds {
                current.append(workout)
                currentEnd = max(currentEnd, workoutEnd)
            } else {
                sessions.append(Session(workouts: current, startDate: currentStart, endDate: currentEnd))
                current = [workout]
                currentStart = workoutStart
                currentEnd = workoutEnd
            }
        }

        sessions.append(Session(workouts: current, startDate: currentStart, endDate: currentEnd))
        return sessions
    }

    private func title(for session: Session, averageDurationMinutes: Double) -> String {
        let prefix = timeBucketPrefix(for: session.startDate)
        let components = session.labels.prefix(2).joined(separator: " + ")
        let suffix = Int(averageDurationMinutes.rounded())
        if components.isEmpty {
            return "\(prefix) \(suffix)min"
        }
        return "\(prefix) \(components) \(suffix)min"
    }

    private func timeBucketPrefix(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return String(localized: "Morning")
        case 11..<17: return String(localized: "Day")
        case 17..<22: return String(localized: "Evening")
        default: return String(localized: "Night")
        }
    }
}
