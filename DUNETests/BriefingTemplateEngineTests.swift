import Foundation
import Testing
@testable import DUNE

@Suite("BriefingTemplateEngine")
struct BriefingTemplateEngineTests {

    // MARK: - Helpers

    private func makeData(
        conditionScore: Int = 75,
        conditionStatus: ConditionScore.Status = .good,
        hrvDelta: Double? = nil,
        rhrDelta: Double? = nil,
        sleepDurationMinutes: Double? = nil,
        recoveryInsight: String? = nil,
        trainingInsight: String? = nil,
        sleepDebtHours: Double? = nil,
        weeklyAverage: Int = 70,
        previousWeekAverage: Int? = nil,
        activeDays: Int = 3,
        goalDays: Int = 5,
        weatherCondition: String? = nil,
        temperature: Double? = nil,
        outdoorFitnessLevel: String? = nil,
        weatherInsight: String? = nil
    ) -> MorningBriefingData {
        MorningBriefingData(
            conditionScore: conditionScore,
            conditionStatus: conditionStatus,
            hrvValue: nil,
            hrvDelta: hrvDelta,
            rhrValue: nil,
            rhrDelta: rhrDelta,
            sleepDurationMinutes: sleepDurationMinutes,
            deepSleepMinutes: nil,
            sleepDeltaMinutes: nil,
            recoveryInsight: recoveryInsight,
            trainingInsight: trainingInsight,
            sleepDebtHours: sleepDebtHours,
            recentScores: [],
            weeklyAverage: weeklyAverage,
            previousWeekAverage: previousWeekAverage,
            activeDays: activeDays,
            goalDays: goalDays,
            weatherCondition: weatherCondition,
            temperature: temperature,
            outdoorFitnessLevel: outdoorFitnessLevel,
            weatherInsight: weatherInsight
        )
    }

    // MARK: - Recovery Title

    @Test("Recovery title matches condition status", arguments: [
        (ConditionScore.Status.excellent, "Excellent condition today"),
        (.good, "Good condition today"),
        (.fair, "Fair condition today"),
        (.tired, "Your body needs rest"),
        (.warning, "Recovery recommended"),
    ])
    func recoveryTitle(status: ConditionScore.Status, expected: String) {
        let data = makeData(conditionStatus: status)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.recoveryTitle == String(localized: String.LocalizationValue(expected)))
    }

    // MARK: - Recovery Message

    @Test("Recovery message includes sleep duration")
    func recoveryMessageWithSleep() {
        let data = makeData(sleepDurationMinutes: 450) // 7h 30m
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.recoveryMessage == String(localized: "You slept \(7)h \(30)m last night."))
    }

    @Test("Recovery message shows whole hours without minutes")
    func recoveryMessageWholeHours() {
        let data = makeData(sleepDurationMinutes: 480) // 8h 0m
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.recoveryMessage == String(localized: "You slept \(8) hours last night."))
    }

    @Test("Recovery message includes HRV delta up")
    func recoveryMessageHRVUp() {
        let data = makeData(hrvDelta: 5.0)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.recoveryMessage == String(localized: "HRV is up \(5)ms from yesterday."))
    }

    @Test("Recovery message includes HRV delta down")
    func recoveryMessageHRVDown() {
        let data = makeData(hrvDelta: -3.0)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.recoveryMessage == String(localized: "HRV is down \(3)ms from yesterday."))
    }

    @Test("Recovery message includes RHR delta drop")
    func recoveryMessageRHRDrop() {
        let data = makeData(rhrDelta: -2.0)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.recoveryMessage == String(localized: "RHR dropped \(2)bpm — a positive sign."))
    }

    @Test("Recovery message includes RHR delta rise")
    func recoveryMessageRHRRise() {
        let data = makeData(rhrDelta: 3.0)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.recoveryMessage == String(localized: "RHR is up \(3)bpm from yesterday."))
    }

    @Test("Recovery message falls back to condition score when no deltas")
    func recoveryMessageFallback() {
        let data = makeData(conditionScore: 82)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.recoveryMessage.contains("82"))
    }

    // MARK: - Guide

    @Test("Guide title uses recommended intensity")
    func guideTitle() {
        let data = makeData(conditionStatus: .excellent)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.guideTitle == String(localized: "High Intensity"))
    }

    @Test("Guide message uses training insight when available")
    func guideMessageWithInsight() {
        let data = makeData(trainingInsight: "Push day recommended")
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.guideMessage.contains("Push day recommended"))
    }

    @Test("Guide message uses condition-based fallback")
    func guideMessageFallback() {
        let data = makeData(conditionStatus: .excellent)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.guideMessage.contains(String(localized: "Great day for a challenging workout.")))
    }

    @Test("Guide message includes sleep debt advisory")
    func guideMessageSleepDebt() {
        let data = makeData(sleepDebtHours: 2.5)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.guideMessage.contains("2.5"))
    }

    @Test("Guide message skips negligible sleep debt")
    func guideMessageNegligibleSleepDebt() {
        let data = makeData(sleepDebtHours: 0.3)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(!sections.guideMessage.contains("Sleep debt"))
    }

    // MARK: - Weekly Context

    @Test("Weekly title trending up")
    func weeklyTitleUp() {
        let data = makeData(weeklyAverage: 75, previousWeekAverage: 60)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weeklyTitle == String(localized: "Trending up this week"))
    }

    @Test("Weekly title trending down")
    func weeklyTitleDown() {
        let data = makeData(weeklyAverage: 55, previousWeekAverage: 70)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weeklyTitle == String(localized: "Trending down this week"))
    }

    @Test("Weekly title neutral when no previous data")
    func weeklyTitleNeutral() {
        let data = makeData(previousWeekAverage: nil)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weeklyTitle == String(localized: "Your week so far"))
    }

    @Test("Weekly message shows goal completed")
    func weeklyGoalCompleted() {
        let data = makeData(activeDays: 5, goalDays: 5)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weeklyMessage.contains(String(localized: "Weekly exercise goal completed!")))
    }

    @Test("Weekly message shows progress")
    func weeklyProgress() {
        let data = makeData(activeDays: 3, goalDays: 5)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weeklyMessage.contains("3/5"))
    }

    @Test("Weekly message shows no workouts yet")
    func weeklyNoWorkouts() {
        let data = makeData(activeDays: 0, goalDays: 4)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weeklyMessage.contains(String(localized: "No workouts yet this week — start today!")))
    }

    // MARK: - Weather

    @Test("Weather sections are nil when no weather data")
    func weatherNil() {
        let data = makeData()
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weatherTitle == nil)
        #expect(sections.weatherMessage == nil)
    }

    @Test("Weather title includes condition and temperature")
    func weatherTitleWithTemp() {
        let data = makeData(weatherCondition: "Sunny", temperature: 22.0)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weatherTitle == "Sunny 22°")
    }

    @Test("Weather title without temperature")
    func weatherTitleNoTemp() {
        let data = makeData(weatherCondition: "Cloudy")
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weatherTitle == "Cloudy")
    }

    @Test("Weather message uses insight when available")
    func weatherMessageInsight() {
        let data = makeData(weatherCondition: "Rain", weatherInsight: "Bring an umbrella")
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weatherMessage == "Bring an umbrella")
    }

    @Test("Weather message uses fitness level fallback")
    func weatherMessageFitnessLevel() {
        let data = makeData(weatherCondition: "Sunny", outdoorFitnessLevel: "Good")
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weatherMessage?.contains("Good") == true)
    }
}
