import Foundation

/// A single personal record entry for a specific workout activity type.
struct PersonalRecord: Codable, Sendable {
    let type: PersonalRecordType
    let value: Double
    let date: Date
    let workoutID: String

    // Optional HealthKit context for richer PR display.
    let heartRateAvg: Double?
    let heartRateMax: Double?
    let heartRateMin: Double?
    let stepCount: Double?
    let weatherTemperature: Double?
    let weatherCondition: Int?
    let weatherHumidity: Double?
    let isIndoor: Bool?

    init(
        type: PersonalRecordType,
        value: Double,
        date: Date,
        workoutID: String,
        heartRateAvg: Double? = nil,
        heartRateMax: Double? = nil,
        heartRateMin: Double? = nil,
        stepCount: Double? = nil,
        weatherTemperature: Double? = nil,
        weatherCondition: Int? = nil,
        weatherHumidity: Double? = nil,
        isIndoor: Bool? = nil
    ) {
        self.type = type
        self.value = value
        self.date = date
        self.workoutID = workoutID
        self.heartRateAvg = heartRateAvg
        self.heartRateMax = heartRateMax
        self.heartRateMin = heartRateMin
        self.stepCount = stepCount
        self.weatherTemperature = weatherTemperature
        self.weatherCondition = weatherCondition
        self.weatherHumidity = weatherHumidity
        self.isIndoor = isIndoor
    }
}

/// Training Load data point for a single day.
struct TrainingLoad: Identifiable, Sendable {
    let id: Date
    let date: Date
    let load: Double
    let source: LoadSource

    enum LoadSource: String, Codable, Sendable {
        case effort      // Apple Workout Effort Score
        case rpe         // User-entered RPE
        case trimp       // HR-based TRIMP calculation
    }
}

// MARK: - Workout Rewards

/// Reward event type emitted when a workout triggers an achievement.
enum WorkoutRewardEventKind: String, Codable, Sendable, Hashable {
    case milestone
    case personalRecord
    case badgeUnlocked
    case levelUp

    /// Higher value means higher notification priority.
    var priority: Int {
        switch self {
        case .milestone: 1
        case .personalRecord: 2
        case .badgeUnlocked: 3
        case .levelUp: 4
        }
    }
}

/// Single achievement record stored for reward history and notification selection.
struct WorkoutRewardEvent: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let workoutID: String
    let activityTypeRawValue: String
    let date: Date
    let kind: WorkoutRewardEventKind
    let title: String
    let detail: String
    let pointsAwarded: Int
    let levelAfterEvent: Int?
}

/// Aggregated reward status used by Activity PR and history screens.
struct WorkoutRewardSummary: Codable, Sendable, Hashable {
    let level: Int
    let totalPoints: Int
    let badgeCount: Int

    static let empty = WorkoutRewardSummary(level: 1, totalPoints: 0, badgeCount: 0)
}

/// Result of evaluating a workout against reward rules.
struct WorkoutRewardOutcome: Sendable {
    let events: [WorkoutRewardEvent]
    let representativeEvent: WorkoutRewardEvent?
    let summary: WorkoutRewardSummary
}

// MARK: - Badge Evaluation Stats

/// Aggregated statistics used to evaluate badge unlock conditions.
struct BadgeEvaluationStats: Sendable {
    let totalPRCount: Int
    let distinctPRKindCount: Int
    let totalVolumeKg: Double
    let bestStreakDays: Int
    let totalWorkoutCount: Int
    let daysSinceFirstWorkout: Int
    let bestImprovementPercent: Double
    /// Fastest pace in seconds per km (0 = no data).
    let bestPacePerKm: Double

    static let empty = BadgeEvaluationStats(
        totalPRCount: 0, distinctPRKindCount: 0, totalVolumeKg: 0,
        bestStreakDays: 0, totalWorkoutCount: 0, daysSinceFirstWorkout: 0,
        bestImprovementPercent: 0, bestPacePerKm: 0
    )
}

// MARK: - Level Tier System

/// Named tier within the reward level progression.
struct RewardLevelTier: Sendable, Hashable {
    let level: Int
    let name: String
    let minPoints: Int

    private static let tiers: [(name: String, minLevel: Int, minPoints: Int)] = [
        ("Beginner", 1, 0),
        ("Dedicated", 5, 800),
        ("Ironclad", 10, 1_800),
        ("Titan", 15, 2_800),
        ("Legend", 20, 3_800),
        ("Immortal", 25, 4_800)
    ]

    static func tier(for level: Int) -> RewardLevelTier {
        let matched = tiers.last { level >= $0.minLevel } ?? tiers[0]
        return RewardLevelTier(level: level, name: matched.name, minPoints: matched.minPoints)
    }

    static func nextTier(for level: Int) -> RewardLevelTier? {
        guard let next = tiers.first(where: { $0.minLevel > level }) else { return nil }
        return RewardLevelTier(level: next.minLevel, name: next.name, minPoints: next.minPoints)
    }

    /// Returns progress toward next level: (currentPoints, pointsForNextLevel, fraction 0..1).
    static func levelProgress(totalPoints: Int, currentLevel: Int) -> (current: Int, needed: Int, fraction: Double) {
        let pointsPerLevel = 200
        let currentLevelStart = max(0, (currentLevel - 1) * pointsPerLevel)
        let nextLevelStart = currentLevel * pointsPerLevel
        let progressInLevel = totalPoints - currentLevelStart
        let needed = nextLevelStart - currentLevelStart
        let fraction = needed > 0 ? min(1.0, Double(progressInLevel) / Double(needed)) : 1.0
        return (current: progressInLevel, needed: needed, fraction: fraction)
    }

    static let allTierMilestones: [(level: Int, name: String)] = tiers.map { ($0.minLevel, $0.name) }
}

// MARK: - Badge Definitions

/// Category for grouping workout badges.
enum WorkoutBadgeCategory: String, Sendable, Hashable, CaseIterable {
    case prRecord
    case volume
    case streak
    case milestone
    case improvement
}

/// Definition of a workout badge with unlock status.
struct WorkoutBadgeDefinition: Identifiable, Sendable, Hashable {
    let id: String
    let category: WorkoutBadgeCategory
    let name: String
    let description: String
    let iconName: String
    let isUnlocked: Bool
    let unlockedDate: Date?

    static func allDefinitions(unlockedKeys: Set<String>, eventDates: [String: Date] = [:]) -> [WorkoutBadgeDefinition] {
        let defs: [(id: String, cat: WorkoutBadgeCategory, name: String, desc: String, icon: String)] = [
            // PR badges
            ("badge-first-pr", .prRecord, String(localized: "First PR"), String(localized: "Achieve your first personal record"), "trophy.fill"),
            ("badge-10-prs", .prRecord, String(localized: "PR Collector"), String(localized: "Achieve 10 personal records"), "trophy.circle.fill"),
            ("badge-50-prs", .prRecord, String(localized: "PR Master"), String(localized: "Achieve 50 personal records"), "medal.star.fill"),
            ("badge-all-kinds", .prRecord, String(localized: "All-Rounder"), String(localized: "Set a PR in every category"), "star.circle.fill"),
            // Volume badges
            ("badge-1k-volume", .volume, String(localized: "1K Club"), String(localized: "Lift 1,000 kg total volume"), "scalemass.fill"),
            ("badge-10k-volume", .volume, String(localized: "10K Club"), String(localized: "Lift 10,000 kg total volume"), "dumbbell.fill"),
            ("badge-100k-volume", .volume, String(localized: "Iron Century"), String(localized: "Lift 100,000 kg total volume"), "figure.strengthtraining.traditional"),
            // Streak badges
            ("badge-7-streak", .streak, String(localized: "Week Warrior"), String(localized: "7-day workout streak"), "flame.fill"),
            ("badge-30-streak", .streak, String(localized: "Monthly Master"), String(localized: "30-day workout streak"), "flame.circle.fill"),
            ("badge-100-streak", .streak, String(localized: "Century Streak"), String(localized: "100-day workout streak"), "bolt.heart.fill"),
            // Milestone badges
            ("badge-first-workout", .milestone, String(localized: "First Step"), String(localized: "Complete your first workout"), "figure.walk"),
            ("badge-100-workouts", .milestone, String(localized: "Centurion"), String(localized: "Complete 100 workouts"), "figure.run"),
            ("badge-365-days", .milestone, String(localized: "Year Strong"), String(localized: "1 year of training"), "calendar.badge.checkmark"),
            // Improvement badges
            ("badge-10pct-improve", .improvement, String(localized: "Progress"), String(localized: "10% improvement on any lift"), "arrow.up.right"),
            ("badge-double-lift", .improvement, String(localized: "Double Up"), String(localized: "Double your weight on any lift"), "arrow.up.circle.fill"),
            ("badge-sub5-pace", .improvement, String(localized: "Speed Demon"), String(localized: "Sub 5-min/km pace"), "hare.fill"),
        ]

        return defs.map { def in
            WorkoutBadgeDefinition(
                id: def.id,
                category: def.cat,
                name: def.name,
                description: def.desc,
                iconName: def.icon,
                isUnlocked: unlockedKeys.contains(def.id),
                unlockedDate: eventDates[def.id]
            )
        }
    }

    /// Evaluates which badge IDs should be unlocked based on cumulative stats.
    /// Returns only newly unlockable IDs (not already in `currentUnlocked`).
    static func evaluateUnlocks(
        stats: BadgeEvaluationStats,
        currentUnlocked: Set<String>
    ) -> [String] {
        let rules: [(id: String, check: (BadgeEvaluationStats) -> Bool)] = [
            ("badge-first-pr", { $0.totalPRCount >= 1 }),
            ("badge-10-prs", { $0.totalPRCount >= 10 }),
            ("badge-50-prs", { $0.totalPRCount >= 50 }),
            ("badge-all-kinds", { $0.distinctPRKindCount >= 5 }),
            ("badge-1k-volume", { $0.totalVolumeKg >= 1_000 }),
            ("badge-10k-volume", { $0.totalVolumeKg >= 10_000 }),
            ("badge-100k-volume", { $0.totalVolumeKg >= 100_000 }),
            ("badge-7-streak", { $0.bestStreakDays >= 7 }),
            ("badge-30-streak", { $0.bestStreakDays >= 30 }),
            ("badge-100-streak", { $0.bestStreakDays >= 100 }),
            ("badge-first-workout", { $0.totalWorkoutCount >= 1 }),
            ("badge-100-workouts", { $0.totalWorkoutCount >= 100 }),
            ("badge-365-days", { $0.daysSinceFirstWorkout >= 365 }),
            ("badge-10pct-improve", { $0.bestImprovementPercent >= 10 }),
            ("badge-double-lift", { $0.bestImprovementPercent >= 100 }),
            ("badge-sub5-pace", { $0.bestPacePerKm > 0 && $0.bestPacePerKm <= 300 }),
        ]

        return rules.compactMap { rule in
            guard !currentUnlocked.contains(rule.id), rule.check(stats) else { return nil }
            return rule.id
        }
    }
}

// MARK: - Fun Comparisons

/// Dynamic comparison of workout metrics to real-world objects.
struct FunComparison: Identifiable, Sendable, Hashable {
    let id: String
    let metric: String
    let value: Double
    let comparison: String
    let iconName: String

    private static let volumeComparisons: [(threshold: Double, text: String, icon: String)] = [
        (400, "a grand piano", "pianokeys"),
        (1_500, "a small car", "car.fill"),
        (6_000, "an elephant", "pawprint.fill"),
        (50_000, "a city bus", "bus.fill"),
        (100_000, "a blue whale", "water.waves"),
    ]

    private static let distanceComparisons: [(threshold: Double, text: String, icon: String)] = [
        (5_000, "across Central Park", "leaf.fill"),
        (42_195, "a full marathon", "figure.run"),
        (100_000, "Seoul to Suwon", "map.fill"),
        (325_000, "Seoul to Busan", "airplane"),
    ]

    private static let calorieComparisons: [(threshold: Double, text: String, icon: String)] = [
        (500, "a slice of pizza", "fork.knife"),
        (2_000, "a full day's meals", "takeoutbag.and.cup.and.straw.fill"),
        (10_000, "5 days of meals", "cart.fill"),
    ]

    static func generate(totalVolume: Double, totalDistance: Double, totalCalories: Double) -> [FunComparison] {
        var results: [FunComparison] = []

        if totalVolume > 0, let match = volumeComparisons.last(where: { totalVolume >= $0.threshold }) {
            let multiplier = Int(totalVolume / match.threshold)
            let text = multiplier > 1
                ? String(localized: "\(multiplier)x \(match.text)")
                : String(localized: "≈ \(match.text)")
            results.append(FunComparison(
                id: "volume-compare",
                metric: String(localized: "Total Volume"),
                value: totalVolume,
                comparison: text,
                iconName: match.icon
            ))
        }

        if totalDistance > 0, let match = distanceComparisons.last(where: { totalDistance >= $0.threshold }) {
            let multiplier = Int(totalDistance / match.threshold)
            let text = multiplier > 1
                ? String(localized: "\(multiplier)x \(match.text)")
                : String(localized: "≈ \(match.text)")
            results.append(FunComparison(
                id: "distance-compare",
                metric: String(localized: "Total Distance"),
                value: totalDistance,
                comparison: text,
                iconName: match.icon
            ))
        }

        if totalCalories > 0, let match = calorieComparisons.last(where: { totalCalories >= $0.threshold }) {
            let multiplier = Int(totalCalories / match.threshold)
            let text = multiplier > 1
                ? String(localized: "\(multiplier)x \(match.text)")
                : String(localized: "≈ \(match.text)")
            results.append(FunComparison(
                id: "calories-compare",
                metric: String(localized: "Total Calories"),
                value: totalCalories,
                comparison: text,
                iconName: match.icon
            ))
        }

        return results
    }
}
