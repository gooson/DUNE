import Foundation

/// Data container for morning briefing sheet.
/// Assembled from DashboardViewModel's already-loaded health data.
struct MorningBriefingData: Sendable {
    // MARK: - Section 1: Recovery Summary

    let conditionScore: Int
    let conditionStatus: ConditionScore.Status
    let hrvValue: Double?
    let hrvDelta: Double?
    let rhrValue: Double?
    let rhrDelta: Double?
    let sleepDurationMinutes: Double?
    let deepSleepMinutes: Double?
    let sleepDeltaMinutes: Int?

    // MARK: - Section 2: Today's Guide

    let recoveryInsight: String?
    let trainingInsight: String?
    let sleepDebtHours: Double?

    // MARK: - Section 3: Weekly Context

    struct DailyScore: Sendable {
        let date: Date
        let score: Int
    }

    let recentScores: [DailyScore]
    let weeklyAverage: Int
    let previousWeekAverage: Int?
    let activeDays: Int
    let goalDays: Int

    // MARK: - Section 4: Weather

    let weatherCondition: String?
    let temperature: Double?
    let outdoorFitnessLevel: String?
    let weatherInsight: String?

    // MARK: - Section Visibility

    var hasSleepData: Bool { sleepDurationMinutes != nil }
    var hasWeatherData: Bool { weatherCondition != nil }
    var hasRecoveryInsight: Bool { recoveryInsight != nil }
    var hasTrainingInsight: Bool { trainingInsight != nil }

    /// Recommended exercise intensity based on condition status.
    var recommendedIntensity: String {
        switch conditionStatus {
        case .excellent: String(localized: "High Intensity")
        case .good: String(localized: "Moderate Intensity")
        case .fair: String(localized: "Light Intensity")
        case .tired, .warning: String(localized: "Rest or Light Activity")
        }
    }
}
