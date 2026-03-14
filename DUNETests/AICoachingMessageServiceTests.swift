import Foundation
import Testing
@testable import DUNE

@Suite("AICoachingMessageService")
struct AICoachingMessageServiceTests {

    let sut = AICoachingMessageService()

    // MARK: - Fallback Behavior

    @Test("Returns original insight when Foundation Models are unavailable")
    func fallbackWhenUnavailable() async {
        let unavailableSUT = AICoachingMessageService(availabilityProvider: { false })
        let insight = makeTestInsight()
        let input = makeTestInput()

        let result = await unavailableSUT.enhance(insight: insight, context: input)

        #expect(result.id == insight.id)
        #expect(result.title == insight.title)
        #expect(result.message == insight.message)
        #expect(result.priority == insight.priority)
        #expect(result.category == insight.category)
        #expect(result.iconName == insight.iconName)
        #expect(result.actionHint == insight.actionHint)
    }

    @Test("Injected availability is respected")
    func injectedAvailabilityIsRespected() {
        let unavailableSUT = AICoachingMessageService(availabilityProvider: { false })
        #expect(!unavailableSUT.isAvailable)
    }

    // MARK: - Prompt Construction

    @Test("Prompt includes condition score")
    func promptIncludesConditionScore() {
        let insight = makeTestInsight()
        let input = makeTestInput(conditionScore: ConditionScore(
            score: 75,
            date: Date(),
            contributions: [],
            detail: nil
        ))

        let prompt = sut.buildPrompt(insight: insight, context: input)

        #expect(prompt.contains("75/100"))
        #expect(prompt.contains("good"))
    }

    @Test("Prompt includes sleep data")
    func promptIncludesSleepData() {
        let insight = makeTestInsight()
        let input = makeTestInput(sleepMinutes: 450)

        let prompt = sut.buildPrompt(insight: insight, context: input)

        #expect(prompt.contains("7h 30m"))
    }

    @Test("Prompt includes active days")
    func promptIncludesActiveDays() {
        let insight = makeTestInsight()
        let input = makeTestInput(activeDaysThisWeek: 3, weeklyGoalDays: 5)

        let prompt = sut.buildPrompt(insight: insight, context: input)

        #expect(prompt.contains("3/5"))
    }

    @Test("Prompt includes template message")
    func promptIncludesTemplateMessage() {
        let insight = makeTestInsight(message: "Take it easy today.")
        let input = makeTestInput()

        let prompt = sut.buildPrompt(insight: insight, context: input)

        #expect(prompt.contains("Take it easy today."))
    }

    @Test("Prompt includes category and priority")
    func promptIncludesCategoryAndPriority() {
        let insight = makeTestInsight(category: .recovery, priority: .high)
        let input = makeTestInput()

        let prompt = sut.buildPrompt(insight: insight, context: input)

        #expect(prompt.contains("recovery"))
        #expect(prompt.contains("2"))
    }

    // MARK: - Protocol Conformance

    @Test("Mock enhancer can replace messages")
    func mockEnhancerReplacesMessages() async {
        let mock = MockCoachingMessageEnhancer(enhancedMessage: "AI says: rest well!")
        let insight = makeTestInsight(message: "Original template")
        let input = makeTestInput()

        let result = await mock.enhance(insight: insight, context: input)

        #expect(result.message == "AI says: rest well!")
        #expect(result.id == insight.id)
    }

    // MARK: - Helpers

    private func makeTestInsight(
        message: String = "Test coaching message",
        category: InsightCategory = .general,
        priority: InsightPriority = .standard
    ) -> CoachingInsight {
        CoachingInsight(
            id: "test-insight",
            priority: priority,
            category: category,
            title: "Test Title",
            message: message,
            iconName: "heart.fill",
            actionHint: nil
        )
    }

    private func makeTestInput(
        conditionScore: ConditionScore? = nil,
        sleepMinutes: Double? = nil,
        activeDaysThisWeek: Int = 0,
        weeklyGoalDays: Int = 4
    ) -> CoachingInput {
        CoachingInput(
            conditionScore: conditionScore,
            fatigueStates: [],
            sleepScore: nil,
            sleepMinutes: sleepMinutes,
            deepSleepMinutes: nil,
            workoutStreak: nil,
            hrvTrend: .insufficient,
            sleepTrend: .insufficient,
            activeDaysThisWeek: activeDaysThisWeek,
            weeklyGoalDays: weeklyGoalDays,
            daysSinceLastWorkout: nil,
            workoutSuggestion: nil,
            recentPRExerciseName: nil,
            currentStreakMilestone: nil,
            weather: nil
        )
    }
}

// MARK: - Mock

private struct MockCoachingMessageEnhancer: CoachingMessageEnhancing {
    let enhancedMessage: String

    func enhance(insight: CoachingInsight, context: CoachingInput) async -> CoachingInsight {
        CoachingInsight(
            id: insight.id,
            priority: insight.priority,
            category: insight.category,
            title: insight.title,
            message: enhancedMessage,
            iconName: insight.iconName,
            actionHint: insight.actionHint
        )
    }
}
