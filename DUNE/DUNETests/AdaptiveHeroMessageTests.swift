import Testing
@testable import DUNE

@Suite("Adaptive Hero Message")
struct AdaptiveHeroMessageTests {
    private let engine = CoachingEngine()

    private func makeScore(status: ConditionScore.Status) -> ConditionScore {
        let score: Int
        switch status {
        case .excellent: score = 90
        case .good: score = 75
        case .fair: score = 55
        case .tired: score = 35
        case .warning: score = 20
        }
        return ConditionScore(score: score, date: Date())
    }

    @Test("Morning + good condition = workout encouragement")
    func morningGoodCondition() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 7,
            conditionScore: makeScore(status: .good),
            sleepDebtMinutes: 0,
            todayWorkoutDone: false
        )
        #expect(msg.icon == "sun.max.fill")
        #expect(!msg.message.isEmpty)
    }

    @Test("Morning + workout already done")
    func morningWorkoutDone() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 8,
            conditionScore: makeScore(status: .good),
            sleepDebtMinutes: 0,
            todayWorkoutDone: true
        )
        #expect(msg.icon == "checkmark.circle.fill")
    }

    @Test("Morning + poor condition = rest message")
    func morningPoorCondition() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 7,
            conditionScore: makeScore(status: .tired),
            sleepDebtMinutes: 0,
            todayWorkoutDone: false
        )
        #expect(msg.icon == "moon.zzz.fill")
    }

    @Test("Midday + workout done = stretch message")
    func middayWorkoutDone() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 12,
            conditionScore: makeScore(status: .good),
            sleepDebtMinutes: 0,
            todayWorkoutDone: true
        )
        #expect(msg.icon == "sparkles")
    }

    @Test("Midday + good condition = encouragement")
    func middayGoodCondition() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 11,
            conditionScore: makeScore(status: .excellent),
            sleepDebtMinutes: 0,
            todayWorkoutDone: false
        )
        #expect(msg.icon == "figure.run")
    }

    @Test("Afternoon + no workout = evening session suggestion")
    func afternoonNoWorkout() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 18,
            conditionScore: makeScore(status: .good),
            sleepDebtMinutes: 0,
            todayWorkoutDone: false
        )
        #expect(msg.icon == "sunset.fill")
    }

    @Test("Evening + sleep debt = early bedtime message")
    func eveningSleepDebt() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 22,
            conditionScore: makeScore(status: .fair),
            sleepDebtMinutes: 120,
            todayWorkoutDone: false
        )
        #expect(msg.icon == "bed.double.fill")
    }

    @Test("Night = sleep message")
    func nightMessage() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 2,
            conditionScore: nil,
            sleepDebtMinutes: nil,
            todayWorkoutDone: false
        )
        #expect(msg.icon == "moon.fill")
    }

    @Test("Boundary: hour 6 = morning")
    func boundaryMorning() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 6,
            conditionScore: makeScore(status: .good),
            sleepDebtMinutes: 0,
            todayWorkoutDone: false
        )
        #expect(msg.icon == "sun.max.fill")
    }

    @Test("Boundary: hour 22 = evening")
    func boundaryEvening() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 22,
            conditionScore: makeScore(status: .good),
            sleepDebtMinutes: 0,
            todayWorkoutDone: false
        )
        #expect(msg.icon == "moon.stars.fill")
    }

    @Test("No condition score + morning = rest message")
    func noScoreMorning() {
        let msg = engine.generateAdaptiveHeroMessage(
            hour: 8,
            conditionScore: nil,
            sleepDebtMinutes: nil,
            todayWorkoutDone: false
        )
        // No condition score falls through to "take it easy" path
        #expect(msg.icon == "moon.zzz.fill")
    }
}
