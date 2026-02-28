import Foundation
import Testing
@testable import DUNE

@Suite("CoachingEngine")
struct CoachingEngineTests {
    let engine = CoachingEngine()

    private func makeInput(
        conditionScore: ConditionScore? = nil,
        fatigueStates: [MuscleFatigueState] = [],
        sleepScore: Int? = nil,
        sleepMinutes: Double? = nil,
        deepSleepMinutes: Double? = nil,
        workoutStreak: WorkoutStreak? = nil,
        hrvTrend: TrendAnalysis = .insufficient,
        sleepTrend: TrendAnalysis = .insufficient,
        activeDaysThisWeek: Int = 0,
        weeklyGoalDays: Int = 5,
        daysSinceLastWorkout: Int? = nil,
        workoutSuggestion: WorkoutSuggestion? = nil,
        recentPRExerciseName: String? = nil,
        currentStreakMilestone: Int? = nil
    ) -> CoachingInput {
        CoachingInput(
            conditionScore: conditionScore,
            fatigueStates: fatigueStates,
            sleepScore: sleepScore,
            sleepMinutes: sleepMinutes,
            deepSleepMinutes: deepSleepMinutes,
            workoutStreak: workoutStreak,
            hrvTrend: hrvTrend,
            sleepTrend: sleepTrend,
            activeDaysThisWeek: activeDaysThisWeek,
            weeklyGoalDays: weeklyGoalDays,
            daysSinceLastWorkout: daysSinceLastWorkout,
            workoutSuggestion: workoutSuggestion,
            recentPRExerciseName: recentPRExerciseName,
            currentStreakMilestone: currentStreakMilestone
        )
    }

    // MARK: - Always produces output

    @Test("Always returns a focus insight even with minimal input")
    func alwaysReturnsFocus() {
        let output = engine.generate(from: makeInput())
        #expect(!output.focusInsight.title.isEmpty)
        #expect(!output.focusInsight.message.isEmpty)
        #expect(!output.focusInsight.iconName.isEmpty)
    }

    // MARK: - Priority ordering

    @Test("Focus insight is the highest priority")
    func focusIsHighestPriority() {
        let input = makeInput(
            conditionScore: ConditionScore(score: 15, date: Date()),
            sleepMinutes: 300,
            activeDaysThisWeek: 2,
            weeklyGoalDays: 5
        )
        let output = engine.generate(from: input)

        // Focus should have priority <= all cards
        for card in output.insightCards {
            #expect(output.focusInsight.priority <= card.priority)
        }
    }

    @Test("Insight cards are limited to at most 3")
    func cardsLimitedTo3() {
        let input = makeInput(
            conditionScore: ConditionScore(score: 30, date: Date()),
            sleepMinutes: 250,
            activeDaysThisWeek: 1,
            weeklyGoalDays: 5,
            daysSinceLastWorkout: 4
        )
        let output = engine.generate(from: input)
        #expect(output.insightCards.count <= 3)
    }

    // MARK: - Recovery triggers

    @Test("Warning condition with falling HRV triggers critical insight")
    func recoveryWarningTrigger() {
        // score < 20 → .warning status
        let input = makeInput(
            conditionScore: ConditionScore(score: 15, date: Date()),
            hrvTrend: TrendAnalysis(direction: .falling, consecutiveDays: 4, changePercent: -15)
        )
        let output = engine.generate(from: input)
        #expect(output.focusInsight.category == .recovery)
        #expect(output.focusInsight.priority == .critical)
    }

    // MARK: - Sleep triggers

    @Test("Low sleep generates sleep insight")
    func lowSleepTrigger() {
        let input = makeInput(
            sleepMinutes: 250
        )
        let output = engine.generate(from: input)
        // Should contain at least one sleep-related insight
        let allInsights = [output.focusInsight] + output.insightCards
        let hasSleep = allInsights.contains { $0.category == .sleep }
        #expect(hasSleep)
    }

    // MARK: - Training triggers

    @Test("Inactivity generates training insight")
    func inactivityTrigger() {
        let input = makeInput(
            activeDaysThisWeek: 0,
            weeklyGoalDays: 5,
            daysSinceLastWorkout: 5
        )
        let output = engine.generate(from: input)
        let allInsights = [output.focusInsight] + output.insightCards
        let hasTraining = allInsights.contains { $0.category == .training }
        #expect(hasTraining)
    }

    // MARK: - Fallback

    @Test("Minimal input produces fallback insight")
    func fallbackInsight() {
        let output = engine.generate(from: makeInput())
        #expect(output.focusInsight.priority == .fallback)
    }

    // MARK: - Insight properties

    @Test("All insights have valid IDs and icon names")
    func insightProperties() {
        let input = makeInput(
            conditionScore: ConditionScore(score: 50, date: Date()),
            sleepMinutes: 400,
            activeDaysThisWeek: 3
        )
        let output = engine.generate(from: input)
        let allInsights = [output.focusInsight] + output.insightCards
        for insight in allInsights {
            #expect(!insight.id.isEmpty)
            #expect(!insight.iconName.isEmpty)
            #expect(!insight.title.isEmpty)
            #expect(!insight.message.isEmpty)
        }
    }

    @Test("weeklyGoalDays=0 does not trigger false goal achieved")
    func zeroGoalDaysNoFalsePositive() {
        let input = makeInput(
            activeDaysThisWeek: 0,
            weeklyGoalDays: 0
        )
        let output = engine.generate(from: input)
        let allInsights = [output.focusInsight] + output.insightCards
        let hasGoalAchieved = allInsights.contains { $0.id == "training-goal-achieved" }
        #expect(!hasGoalAchieved)
    }

    @Test("Negative sleep minutes does not crash or produce negative times")
    func negativeSleepMinutesSafe() {
        let input = makeInput(sleepMinutes: -100)
        let output = engine.generate(from: input)
        // Should not crash, and focus insight should still be valid
        #expect(!output.focusInsight.title.isEmpty)
        // Negative sleep should not trigger sleep insights (< 360 guard requires > 0)
        let allInsights = [output.focusInsight] + output.insightCards
        let hasSleep = allInsights.contains { $0.category == .sleep }
        #expect(!hasSleep)
    }

    @Test("Weekly goal completion triggers motivation insight")
    func weeklyGoalCompletionTrigger() {
        let input = makeInput(
            conditionScore: ConditionScore(score: 80, date: Date()),
            activeDaysThisWeek: 5,
            weeklyGoalDays: 5
        )
        let output = engine.generate(from: input)
        let allInsights = [output.focusInsight] + output.insightCards
        // Should contain a training or motivation insight about goal completion
        let hasRelevant = allInsights.contains {
            $0.category == .training || $0.category == .motivation
        }
        #expect(hasRelevant)
    }
}
