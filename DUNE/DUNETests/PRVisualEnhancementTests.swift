import Testing
@testable import DUNE

@Suite("PR Visual Enhancement")
struct PRVisualEnhancementTests {

    // MARK: - RewardLevelTier Tests

    @Suite("Level Tier System")
    struct LevelTierTests {

        @Test("Tier for level 1 is Beginner")
        func tierLevel1() {
            let tier = RewardLevelTier.tier(for: 1)
            #expect(tier.name == "Beginner")
        }

        @Test("Tier for level 4 is Beginner (boundary)")
        func tierLevel4() {
            let tier = RewardLevelTier.tier(for: 4)
            #expect(tier.name == "Beginner")
        }

        @Test("Tier for level 5 is Dedicated")
        func tierLevel5() {
            let tier = RewardLevelTier.tier(for: 5)
            #expect(tier.name == "Dedicated")
        }

        @Test("Tier for level 14 is Ironclad")
        func tierLevel14() {
            let tier = RewardLevelTier.tier(for: 14)
            #expect(tier.name == "Ironclad")
        }

        @Test("Tier for level 15 is Titan")
        func tierLevel15() {
            let tier = RewardLevelTier.tier(for: 15)
            #expect(tier.name == "Titan")
        }

        @Test("Tier for level 25 is Immortal")
        func tierLevel25() {
            let tier = RewardLevelTier.tier(for: 25)
            #expect(tier.name == "Immortal")
        }

        @Test("Tier for level 50 is Immortal (cap)")
        func tierLevel50() {
            let tier = RewardLevelTier.tier(for: 50)
            #expect(tier.name == "Immortal")
        }

        @Test("Next tier from level 1 is Dedicated")
        func nextTierFrom1() {
            let next = RewardLevelTier.nextTier(for: 1)
            #expect(next?.name == "Dedicated")
            #expect(next?.level == 5)
        }

        @Test("Next tier from level 24 is Immortal")
        func nextTierFrom24() {
            let next = RewardLevelTier.nextTier(for: 24)
            #expect(next?.name == "Immortal")
        }

        @Test("No next tier from level 25+")
        func noNextTierFrom25() {
            let next = RewardLevelTier.nextTier(for: 25)
            #expect(next == nil)
        }

        @Test("Level progress fraction at midpoint")
        func levelProgressMidpoint() {
            // Level 3, 400 total points (level starts at 400, ends at 600)
            let progress = RewardLevelTier.levelProgress(totalPoints: 500, currentLevel: 3)
            #expect(progress.current == 100)
            #expect(progress.needed == 200)
            #expect(abs(progress.fraction - 0.5) < 0.01)
        }

        @Test("Level progress at start")
        func levelProgressStart() {
            let progress = RewardLevelTier.levelProgress(totalPoints: 0, currentLevel: 1)
            #expect(progress.fraction == 0.0)
        }

        @Test("Level progress capped at 1.0")
        func levelProgressCapped() {
            let progress = RewardLevelTier.levelProgress(totalPoints: 999, currentLevel: 1)
            #expect(progress.fraction == 1.0)
        }

        @Test("All tier milestones count")
        func tierMilestonesCount() {
            #expect(RewardLevelTier.allTierMilestones.count == 6)
        }
    }

    // MARK: - Badge Definition Tests

    @Suite("Badge Definitions")
    struct BadgeTests {

        @Test("All definitions count is 16")
        func allBadgesCount() {
            let defs = WorkoutBadgeDefinition.allDefinitions(unlockedKeys: [])
            #expect(defs.count == 16)
        }

        @Test("All badges locked by default")
        func allLockedByDefault() {
            let defs = WorkoutBadgeDefinition.allDefinitions(unlockedKeys: [])
            #expect(defs.allSatisfy { !$0.isUnlocked })
        }

        @Test("Specific badge unlocked")
        func specificBadgeUnlocked() {
            let defs = WorkoutBadgeDefinition.allDefinitions(unlockedKeys: ["badge-first-pr"])
            let firstPR = defs.first { $0.id == "badge-first-pr" }
            #expect(firstPR?.isUnlocked == true)
        }

        @Test("Badge categories cover all enum cases")
        func badgeCategoryCoverage() {
            let defs = WorkoutBadgeDefinition.allDefinitions(unlockedKeys: [])
            let categories = Set(defs.map(\.category))
            for category in WorkoutBadgeCategory.allCases {
                #expect(categories.contains(category), "Missing category: \(category)")
            }
        }
    }

    // MARK: - Fun Comparison Tests

    @Suite("Fun Comparisons")
    struct FunComparisonTests {

        @Test("No comparisons for zero values")
        func noComparisonsForZero() {
            let result = FunComparison.generate(totalVolume: 0, totalDistance: 0, totalCalories: 0)
            #expect(result.isEmpty)
        }

        @Test("Volume comparison at 400kg = piano")
        func volumePianoThreshold() {
            let result = FunComparison.generate(totalVolume: 400, totalDistance: 0, totalCalories: 0)
            #expect(result.count == 1)
            #expect(result[0].id == "volume-compare")
        }

        @Test("Volume comparison at 3000kg = 2x small car")
        func volumeCarMultiplier() {
            let result = FunComparison.generate(totalVolume: 3000, totalDistance: 0, totalCalories: 0)
            #expect(result.count == 1)
            // 3000 / 1500 = 2x
            #expect(result[0].comparison.contains("2x"))
        }

        @Test("Distance comparison at marathon")
        func distanceMarathon() {
            let result = FunComparison.generate(totalVolume: 0, totalDistance: 42_195, totalCalories: 0)
            #expect(result.count == 1)
            #expect(result[0].id == "distance-compare")
        }

        @Test("Multiple comparisons at once")
        func multipleComparisons() {
            let result = FunComparison.generate(
                totalVolume: 10_000,
                totalDistance: 100_000,
                totalCalories: 5_000
            )
            #expect(result.count == 3)
        }

        @Test("Below threshold returns empty")
        func belowThreshold() {
            let result = FunComparison.generate(totalVolume: 50, totalDistance: 100, totalCalories: 50)
            #expect(result.isEmpty)
        }
    }

    // MARK: - Delta Value Tests

    @Suite("PR Delta Calculations")
    struct DeltaTests {

        @Test("Positive delta for higher-is-better")
        func positiveDelta() {
            let record = ActivityPersonalRecord(
                id: "test", kind: .strengthWeight, title: "Bench",
                value: 100, date: Date(), isRecent: true, source: .manual,
                previousValue: 90
            )
            #expect(record.deltaValue == 10)
            #expect(record.formattedDelta?.hasPrefix("+") == true)
        }

        @Test("Positive delta for lower-is-better (pace)")
        func positiveDeltaPace() {
            let record = ActivityPersonalRecord(
                id: "test", kind: .fastestPace, title: "Run",
                value: 300, date: Date(), isRecent: true, source: .healthKit,
                previousValue: 330
            )
            // 330 - 300 = 30 seconds improvement
            #expect(record.deltaValue == 30)
        }

        @Test("Nil delta when no previous value")
        func nilDeltaNoPrevious() {
            let record = ActivityPersonalRecord(
                id: "test", kind: .strengthWeight, title: "Bench",
                value: 100, date: Date(), isRecent: true, source: .manual
            )
            #expect(record.deltaValue == nil)
            #expect(record.formattedDelta == nil)
        }

        @Test("Zero delta returns nil formatted")
        func zeroDelta() {
            let record = ActivityPersonalRecord(
                id: "test", kind: .strengthWeight, title: "Bench",
                value: 100, date: Date(), isRecent: true, source: .manual,
                previousValue: 100
            )
            #expect(record.formattedDelta == nil)
        }
    }

    // MARK: - Badge Evaluation Tests

    @Suite("Badge Evaluation Logic")
    struct BadgeEvaluationTests {

        @Test("Zero stats unlocks no badges")
        func zeroStatsNoBadges() {
            let result = WorkoutBadgeDefinition.evaluateUnlocks(
                stats: .empty,
                currentUnlocked: []
            )
            #expect(result.isEmpty)
        }

        @Test("First PR threshold unlocks badge-first-pr")
        func firstPRThreshold() {
            let stats = BadgeEvaluationStats(
                totalPRCount: 1, distinctPRKindCount: 1, totalVolumeKg: 0,
                bestStreakDays: 0, totalWorkoutCount: 1, daysSinceFirstWorkout: 0,
                bestImprovementPercent: 0, bestPacePerKm: 0
            )
            let result = WorkoutBadgeDefinition.evaluateUnlocks(stats: stats, currentUnlocked: [])
            #expect(result.contains("badge-first-pr"))
            #expect(result.contains("badge-first-workout"))
            #expect(!result.contains("badge-10-prs"))
        }

        @Test("Volume thresholds progressive unlock")
        func volumeProgressiveUnlock() {
            let stats1k = BadgeEvaluationStats(
                totalPRCount: 0, distinctPRKindCount: 0, totalVolumeKg: 1_000,
                bestStreakDays: 0, totalWorkoutCount: 0, daysSinceFirstWorkout: 0,
                bestImprovementPercent: 0, bestPacePerKm: 0
            )
            let result1k = WorkoutBadgeDefinition.evaluateUnlocks(stats: stats1k, currentUnlocked: [])
            #expect(result1k.contains("badge-1k-volume"))
            #expect(!result1k.contains("badge-10k-volume"))

            let stats10k = BadgeEvaluationStats(
                totalPRCount: 0, distinctPRKindCount: 0, totalVolumeKg: 10_000,
                bestStreakDays: 0, totalWorkoutCount: 0, daysSinceFirstWorkout: 0,
                bestImprovementPercent: 0, bestPacePerKm: 0
            )
            let result10k = WorkoutBadgeDefinition.evaluateUnlocks(stats: stats10k, currentUnlocked: [])
            #expect(result10k.contains("badge-1k-volume"))
            #expect(result10k.contains("badge-10k-volume"))
        }

        @Test("Streak thresholds")
        func streakThresholds() {
            let stats = BadgeEvaluationStats(
                totalPRCount: 0, distinctPRKindCount: 0, totalVolumeKg: 0,
                bestStreakDays: 30, totalWorkoutCount: 0, daysSinceFirstWorkout: 0,
                bestImprovementPercent: 0, bestPacePerKm: 0
            )
            let result = WorkoutBadgeDefinition.evaluateUnlocks(stats: stats, currentUnlocked: [])
            #expect(result.contains("badge-7-streak"))
            #expect(result.contains("badge-30-streak"))
            #expect(!result.contains("badge-100-streak"))
        }

        @Test("Sub 5-min pace badge")
        func sub5MinPaceBadge() {
            let stats = BadgeEvaluationStats(
                totalPRCount: 0, distinctPRKindCount: 0, totalVolumeKg: 0,
                bestStreakDays: 0, totalWorkoutCount: 0, daysSinceFirstWorkout: 0,
                bestImprovementPercent: 0, bestPacePerKm: 280
            )
            let result = WorkoutBadgeDefinition.evaluateUnlocks(stats: stats, currentUnlocked: [])
            #expect(result.contains("badge-sub5-pace"))
        }

        @Test("Pace at 0 does not unlock speed badge")
        func noPaceNoBadge() {
            let stats = BadgeEvaluationStats(
                totalPRCount: 0, distinctPRKindCount: 0, totalVolumeKg: 0,
                bestStreakDays: 0, totalWorkoutCount: 0, daysSinceFirstWorkout: 0,
                bestImprovementPercent: 0, bestPacePerKm: 0
            )
            let result = WorkoutBadgeDefinition.evaluateUnlocks(stats: stats, currentUnlocked: [])
            #expect(!result.contains("badge-sub5-pace"))
        }

        @Test("Max stats unlocks all 16 badges")
        func maxStatsAllBadges() {
            let stats = BadgeEvaluationStats(
                totalPRCount: 100, distinctPRKindCount: 9, totalVolumeKg: 200_000,
                bestStreakDays: 200, totalWorkoutCount: 500, daysSinceFirstWorkout: 730,
                bestImprovementPercent: 150, bestPacePerKm: 240
            )
            let result = WorkoutBadgeDefinition.evaluateUnlocks(stats: stats, currentUnlocked: [])
            #expect(result.count == 16)
        }

        @Test("Already unlocked badges are excluded")
        func idempotent() {
            let stats = BadgeEvaluationStats(
                totalPRCount: 1, distinctPRKindCount: 1, totalVolumeKg: 0,
                bestStreakDays: 0, totalWorkoutCount: 1, daysSinceFirstWorkout: 0,
                bestImprovementPercent: 0, bestPacePerKm: 0
            )
            let first = WorkoutBadgeDefinition.evaluateUnlocks(stats: stats, currentUnlocked: [])
            #expect(first.contains("badge-first-pr"))

            let second = WorkoutBadgeDefinition.evaluateUnlocks(
                stats: stats,
                currentUnlocked: Set(first)
            )
            #expect(second.isEmpty)
        }
    }
}
