import Foundation

/// One recorded cardio workout. Distance is an actual measured value in meters, never a step or floor count.
struct CardioAtlasSession: Identifiable, Sendable {
    let id: String
    let activityType: WorkoutActivityType
    let date: Date
    let duration: TimeInterval
    let distanceMeters: Double?
    let isIndoor: Bool?

    init(
        id: String,
        activityType: WorkoutActivityType,
        date: Date,
        duration: TimeInterval,
        distanceMeters: Double?,
        isIndoor: Bool? = nil
    ) {
        self.id = id
        self.activityType = activityType
        self.date = date
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.isIndoor = isIndoor
    }
}

struct CardioJourneyProgress: Sendable, Equatable {
    enum Kind: String, Sendable, Hashable {
        case distanceMeters
        case durationSeconds
    }

    let kind: Kind
    let currentContribution: Double
    let total: Double
    let target: Double

    /// Visual progress is capped; `total` preserves the complete recorded value.
    var fraction: Double { min(total / target, 1) }
}

struct CardioAtlasAchievement: Identifiable, Sendable, Equatable {
    enum Kind: String, Sendable, Hashable {
        case singleDistance
        case singleDuration
        case sessionCount
    }

    let id: String
    let kind: Kind
    let threshold: Double
    let achievedValue: Double
    let awardedSessionID: String
    let awardedAt: Date
}

struct CardioAtlasAchievementProgress: Identifiable, Sendable, Equatable {
    let id: String
    let kind: CardioAtlasAchievement.Kind
    let currentValue: Double
    let threshold: Double

    var fraction: Double { min(currentValue / threshold, 1) }
}

/// Recomputed from actual session history so edits and deletions immediately change progress.
struct CardioAtlasProgress: Sendable, Equatable {
    let journey: CardioJourneyProgress
    let achievements: [CardioAtlasAchievement]
    let nextAchievements: [CardioAtlasAchievementProgress]
    let earnedInCurrentSession: [CardioAtlasAchievement]
    let sessionCount: Int
    let activeDaysInCurrentMonth: Int

    static func calculate(
        sessions: [CardioAtlasSession],
        currentSessionID: String,
        distanceGoalMeters: Double = 20_000,
        durationGoalSeconds: Double = 10_800,
        calendar: Calendar = .current
    ) -> CardioAtlasProgress? {
        // Oldest first, with stable ID and payload tie-breakers for duplicate source rows.
        let sorted = sessions.filter(\.isValid).sorted(by: sessionPrecedes)
        var seenIDs = Set<String>()
        let unique = sorted.filter { seenIDs.insert($0.id).inserted }
        guard let currentIndex = unique.firstIndex(where: { $0.id == currentSessionID }) else {
            return nil
        }

        let current = unique[currentIndex]
        let history = unique[...currentIndex].filter { $0.activityType == current.activityType }
        let hasDistance = current.validDistanceMeters != nil
        let kind: CardioJourneyProgress.Kind = hasDistance ? .distanceMeters : .durationSeconds
        let target = hasDistance
            ? validGoal(distanceGoalMeters, fallback: 20_000)
            : validGoal(durationGoalSeconds, fallback: 10_800)
        let contribution = hasDistance ? (current.validDistanceMeters ?? 0) : current.duration
        let total = history.reduce(0.0) { sum, session in
            sum + (hasDistance ? (session.validDistanceMeters ?? 0) : session.duration)
        }
        let journey = CardioJourneyProgress(
            kind: kind,
            currentContribution: contribution,
            total: total.isFinite ? total : Double.greatestFiniteMagnitude,
            target: target
        )

        let distanceThreshold: Double = switch current.activityType {
        case .swimming, .rowing: 1_000
        default: 5_000
        }
        let thresholds: [(CardioAtlasAchievement.Kind, Double)] = [
            (.singleDistance, distanceThreshold),
            (.singleDuration, 1_800),
        ] + [1, 5, 10, 20, 50, 100].map { (.sessionCount, Double($0)) }

        var achievements: [CardioAtlasAchievement] = []
        var earnedIDs = Set<String>()
        var bestDistance = 0.0
        var bestDuration = 0.0
        var count = 0
        for session in history {
            count += 1
            bestDistance = max(bestDistance, session.validDistanceMeters ?? 0)
            bestDuration = max(bestDuration, session.duration)
            for (achievementKind, threshold) in thresholds {
                let id = achievementID(type: current.activityType, kind: achievementKind, threshold: threshold)
                guard !earnedIDs.contains(id) else { continue }
                let value: Double = switch achievementKind {
                case .singleDistance: session.validDistanceMeters ?? 0
                case .singleDuration: session.duration
                case .sessionCount: Double(count)
                }
                guard value >= threshold else { continue }
                earnedIDs.insert(id)
                achievements.append(CardioAtlasAchievement(
                    id: id,
                    kind: achievementKind,
                    threshold: threshold,
                    achievedValue: value,
                    awardedSessionID: session.id,
                    awardedAt: session.date
                ))
            }
        }

        var nextKinds = Set<CardioAtlasAchievement.Kind>()
        let nextAchievements = thresholds.compactMap { achievementKind, threshold -> CardioAtlasAchievementProgress? in
            let id = achievementID(type: current.activityType, kind: achievementKind, threshold: threshold)
            guard !earnedIDs.contains(id), nextKinds.insert(achievementKind).inserted else { return nil }
            let value: Double = switch achievementKind {
            case .singleDistance: bestDistance
            case .singleDuration: bestDuration
            case .sessionCount: Double(count)
            }
            return CardioAtlasAchievementProgress(id: id, kind: achievementKind, currentValue: value, threshold: threshold)
        }

        let month = calendar.dateInterval(of: .month, for: current.date)
        let activeDays = Set(history.compactMap { session -> Date? in
            guard month?.contains(session.date) == true else { return nil }
            return calendar.startOfDay(for: session.date)
        }).count

        return CardioAtlasProgress(
            journey: journey,
            achievements: achievements,
            nextAchievements: nextAchievements,
            earnedInCurrentSession: achievements.filter { $0.awardedSessionID == current.id },
            sessionCount: count,
            activeDaysInCurrentMonth: activeDays
        )
    }

    private static func validGoal(_ value: Double, fallback: Double) -> Double {
        value.isFinite && value > 0 ? value : fallback
    }

    private static func achievementID(
        type: WorkoutActivityType,
        kind: CardioAtlasAchievement.Kind,
        threshold: Double
    ) -> String {
        "\(type.rawValue)-\(kind.rawValue)-\(Int(threshold))"
    }

    private static func sessionPrecedes(_ lhs: CardioAtlasSession, _ rhs: CardioAtlasSession) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        if lhs.activityType.rawValue != rhs.activityType.rawValue {
            return lhs.activityType.rawValue < rhs.activityType.rawValue
        }
        if lhs.duration != rhs.duration { return lhs.duration < rhs.duration }
        if (lhs.distanceMeters ?? 0) != (rhs.distanceMeters ?? 0) {
            return (lhs.distanceMeters ?? 0) < (rhs.distanceMeters ?? 0)
        }
        return (lhs.isIndoor == true ? 1 : 0) < (rhs.isIndoor == true ? 1 : 0)
    }
}

private extension CardioAtlasSession {
    var isValid: Bool {
        !id.isEmpty && date.timeIntervalSinceReferenceDate.isFinite && duration.isFinite && duration > 0
    }

    var validDistanceMeters: Double? {
        guard let distanceMeters, distanceMeters.isFinite, distanceMeters > 0 else { return nil }
        return distanceMeters
    }
}
