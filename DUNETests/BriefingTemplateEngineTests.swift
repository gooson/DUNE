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
        hasScoreHistory: Bool = true,
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
            recentScores: hasScoreHistory ? [.init(date: Date(timeIntervalSince1970: 0), score: weeklyAverage)] : [],
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

    @Test("Recovery highlights separate real sleep and signed HRV without repeating the narrative")
    func recoveryHighlights() {
        let sections = BriefingTemplateEngine.generate(from: makeData(hrvDelta: 24, sleepDurationMinutes: 290))
        #expect(sections.recoveryHighlights.map(\.id) == [.sleep, .hrv])
        #expect(sections.recoveryHighlights[0].value == String(localized: "\(4)h \(50)min"))
        #expect(sections.recoveryHighlights[1].value == "+24 ms")
        #expect(sections.recoverySupportingMessage == nil)
    }

    @Test("Recovery highlights preserve negative and zero HRV changes", arguments: [-3.0, 0.0])
    func signedRecoveryHighlight(delta: Double) {
        let sections = BriefingTemplateEngine.generate(from: makeData(hrvDelta: delta))
        #expect(sections.recoveryHighlights.count == 1)
        #expect(sections.recoveryHighlights[0].value == (delta == 0 ? "0 ms" : "-3 ms"))
    }

    @Test("Fractional HRV changes retain their measured direction", arguments: [
        (-0.5, "-0.5 ms"), (0.5, "+0.5 ms"), (-0.0001, "-0.0001 ms"), (0.0001, "+0.0001 ms")
    ])
    func fractionalRecoveryHighlight(delta: Double, expected: String) {
        let sections = BriefingTemplateEngine.generate(from: makeData(hrvDelta: delta))
        let value = sections.recoveryHighlights[0].value
        #expect(value == expected)
        #expect(value != "0 ms" && value != "+0 ms" && value != "-0 ms")
        #expect(value.hasPrefix(delta < 0 ? "-" : "+"))
    }

    @Test("Whole-hour and zero-minute sleep remain measured values", arguments: [0.0, 480.0])
    func wholeHourHighlight(minutes: Double) {
        let sections = BriefingTemplateEngine.generate(from: makeData(sleepDurationMinutes: minutes))
        #expect(sections.recoveryHighlights.first?.value == String(localized: "\(Int(minutes) / 60)h"))
    }

    @Test("Missing recovery measurements keep the original score fallback")
    func missingRecoveryHighlights() {
        let sections = BriefingTemplateEngine.generate(from: makeData(conditionScore: 82))
        #expect(sections.recoveryHighlights.isEmpty)
        #expect(sections.recoverySupportingMessage == sections.recoveryMessage)
    }

    @Test("Invalid recovery measurements are omitted without numeric conversion traps", arguments: [Double.nan, .infinity, -.infinity, Double(Int.max)])
    func invalidRecoveryHighlights(value: Double) {
        let sections = BriefingTemplateEngine.generate(from: makeData(hrvDelta: value, rhrDelta: value, sleepDurationMinutes: value))
        #expect(sections.recoveryHighlights.isEmpty)
        #expect(sections.recoverySupportingMessage == sections.recoveryMessage)
    }

    @Test("RHR information remains below the recovery highlights")
    func recoverySupportingRHR() {
        let sections = BriefingTemplateEngine.generate(from: makeData(hrvDelta: 2, rhrDelta: -3, sleepDurationMinutes: 420))
        #expect(sections.recoverySupportingMessage == String(localized: "RHR dropped \(3)bpm — a positive sign."))
    }

    @Test("Weekly highlights show actual exercise days and average with a separate remaining count")
    func weeklyHighlights() {
        let sections = BriefingTemplateEngine.generate(from: makeData(weeklyAverage: 56, activeDays: 1, goalDays: 5))
        #expect(sections.weeklyHighlights.map(\.id) == [.exercise, .average])
        #expect(sections.weeklyHighlights[0].value == String(localized: "\(1)/\(5) days"))
        #expect(sections.weeklyHighlights[1].value == String(localized: "\(56) points"))
        #expect(sections.weeklySupportingMessage == String(localized: "\(4) days to go"))
        #expect(sections.weeklyGoalProgress == 0.2)
    }

    @Test("A current-score fallback is not labeled as a weekly average")
    func weeklyHighlightsWithoutHistory() {
        let sections = BriefingTemplateEngine.generate(from: makeData(weeklyAverage: 82, hasScoreHistory: false))
        #expect(sections.weeklyHighlights.map(\.id) == [.exercise])
    }

    @Test("Weekly remaining count never becomes negative after completing the goal", arguments: [5, 7])
    func weeklyHighlightsCompleted(activeDays: Int) {
        let sections = BriefingTemplateEngine.generate(from: makeData(activeDays: activeDays, goalDays: 5))
        #expect(sections.weeklySupportingMessage == String(localized: "Weekly exercise goal completed!"))
        #expect(sections.weeklyGoalProgress == 1)
    }

    @Test("A missing weekly goal does not claim goal completion")
    func weeklyHighlightsWithoutGoal() {
        let sections = BriefingTemplateEngine.generate(from: makeData(activeDays: 0, goalDays: 0))
        #expect(sections.weeklyHighlights[0].value == String(localized: "\(0) days"))
        #expect(sections.weeklySupportingMessage == nil)
        #expect(sections.weeklyGoalProgress == nil)
    }

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

    @Test("Weekly supporting message shows goal completed")
    func weeklyGoalCompleted() {
        let data = makeData(activeDays: 5, goalDays: 5)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weeklySupportingMessage == String(localized: "Weekly exercise goal completed!"))
    }

    @Test("Weekly highlights show progress")
    func weeklyProgress() {
        let data = makeData(activeDays: 3, goalDays: 5)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weeklyHighlights[0].value == String(localized: "\(3)/\(5) days"))
    }

    @Test("Weekly highlights preserve zero recorded exercise days")
    func weeklyNoWorkouts() {
        let data = makeData(activeDays: 0, goalDays: 4)
        let sections = BriefingTemplateEngine.generate(from: data)
        #expect(sections.weeklyHighlights[0].value == String(localized: "\(0)/\(4) days"))
        #expect(sections.weeklySupportingMessage == String(localized: "\(4) days to go"))
        #expect(sections.weeklyGoalProgress == 0)
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
