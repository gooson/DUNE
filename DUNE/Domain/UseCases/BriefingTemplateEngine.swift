import Foundation

/// Template-based text generation for morning briefing sections.
/// Produces localized text from MorningBriefingData without external dependencies.
enum BriefingTemplateEngine {
    struct Highlight: Sendable, Identifiable {
        enum Kind: String, Sendable {
            case sleep, hrv, exercise, average
        }

        let id: Kind
        let title: String
        let value: String
    }

    struct Sections: Sendable {
        let recoveryTitle: String
        let recoveryMessage: String
        let guideTitle: String
        let guideMessage: String
        let weeklyTitle: String
        let weatherTitle: String?
        let weatherMessage: String?
        let recoveryHighlights: [Highlight]
        let recoverySupportingMessage: String?
        let weeklyHighlights: [Highlight]
        let weeklySupportingMessage: String?
        let weeklyGoalProgress: Double?
    }

    static func generate(from data: MorningBriefingData) -> Sections {
        let highlights = recoveryHighlights(for: data)
        return Sections(
            recoveryTitle: recoveryTitle(for: data),
            recoveryMessage: recoveryMessage(for: data),
            guideTitle: guideTitle(for: data),
            guideMessage: guideMessage(for: data),
            weeklyTitle: weeklyTitle(for: data),
            weatherTitle: data.hasWeatherData ? weatherTitle(for: data) : nil,
            weatherMessage: data.hasWeatherData ? weatherMessage(for: data) : nil,
            recoveryHighlights: highlights,
            recoverySupportingMessage: recoverySupportingMessage(for: data, hasHighlights: !highlights.isEmpty),
            weeklyHighlights: weeklyHighlights(for: data),
            weeklySupportingMessage: weeklySupportingMessage(for: data),
            weeklyGoalProgress: data.goalDays > 0
                ? Double(max(0, min(data.activeDays, data.goalDays))) / Double(data.goalDays)
                : nil
        )
    }

    private static func recoveryHighlights(for data: MorningBriefingData) -> [Highlight] {
        var highlights: [Highlight] = []
        if let minutes = data.sleepDurationMinutes,
           minutes.isFinite, minutes >= 0, minutes < Double(Int.max) {
            let hours = Int(minutes) / 60
            let remainder = Int(minutes) % 60
            let value = remainder == 0
                ? String(localized: "\(hours)h")
                : String(localized: "\(hours)h \(remainder)min")
            highlights.append(Highlight(id: .sleep, title: String(localized: "Last Night's Sleep"), value: value))
        }
        if let delta = data.hrvDelta, delta.isFinite, abs(delta) < Double(Int.max) {
            let value = delta == 0
                ? 0.formatted()
                : delta.formatted(.number.precision(.significantDigits(1...3)).sign(strategy: .always()))
            highlights.append(Highlight(id: .hrv, title: String(localized: "HRV vs. Yesterday"), value: "\(value) ms"))
        }
        return highlights
    }

    private static func recoverySupportingMessage(for data: MorningBriefingData, hasHighlights: Bool) -> String? {
        if !hasHighlights { return recoveryMessage(for: data) }
        guard let delta = data.rhrDelta, delta.isFinite, abs(delta) < Double(Int.max), delta != 0 else { return nil }
        let value = Int(abs(delta))
        return delta < 0
            ? String(localized: "RHR dropped \(value)bpm — a positive sign.")
            : String(localized: "RHR is up \(value)bpm from yesterday.")
    }

    private static func weeklyHighlights(for data: MorningBriefingData) -> [Highlight] {
        let activeDays = max(0, data.activeDays)
        let exerciseValue = data.goalDays > 0
            ? String(localized: "\(activeDays)/\(data.goalDays) days")
            : String(localized: "\(activeDays) days")
        var highlights = [Highlight(id: .exercise, title: String(localized: "Exercise Days"), value: exerciseValue)]
        if !data.recentScores.isEmpty {
            highlights.append(Highlight(id: .average, title: String(localized: "Average Condition"), value: String(localized: "\(data.weeklyAverage) points")))
        }
        return highlights
    }

    private static func weeklySupportingMessage(for data: MorningBriefingData) -> String? {
        guard data.goalDays > 0 else { return nil }
        let remaining = data.goalDays - max(0, min(data.activeDays, data.goalDays))
        return remaining == 0
            ? String(localized: "Weekly exercise goal completed!")
            : String(localized: "\(remaining) days to go")
    }

    // MARK: - Recovery Summary

    private static func recoveryTitle(for data: MorningBriefingData) -> String {
        switch data.conditionStatus {
        case .excellent:
            String(localized: "Excellent condition today")
        case .good:
            String(localized: "Good condition today")
        case .fair:
            String(localized: "Fair condition today")
        case .tired:
            String(localized: "Your body needs rest")
        case .warning:
            String(localized: "Recovery recommended")
        }
    }

    private static func recoveryMessage(for data: MorningBriefingData) -> String {
        var parts: [String] = []

        if let sleepMinutes = data.sleepDurationMinutes,
           sleepMinutes.isFinite, sleepMinutes >= 0, sleepMinutes < Double(Int.max) {
            let hours = Int(sleepMinutes) / 60
            let mins = Int(sleepMinutes) % 60
            if mins > 0 {
                parts.append(String(localized: "You slept \(hours)h \(mins)m last night."))
            } else {
                parts.append(String(localized: "You slept \(hours) hours last night."))
            }
        }

        if let hrvDelta = data.hrvDelta, hrvDelta.isFinite, abs(hrvDelta) < Double(Int.max) {
            let absValue = Int(abs(hrvDelta))
            if hrvDelta > 0 {
                parts.append(String(localized: "HRV is up \(absValue)ms from yesterday."))
            } else if hrvDelta < 0 {
                parts.append(String(localized: "HRV is down \(absValue)ms from yesterday."))
            }
        }

        if let rhrDelta = data.rhrDelta, rhrDelta.isFinite, abs(rhrDelta) < Double(Int.max) {
            let absValue = Int(abs(rhrDelta))
            if rhrDelta < 0 {
                parts.append(String(localized: "RHR dropped \(absValue)bpm — a positive sign."))
            } else if rhrDelta > 0 {
                parts.append(String(localized: "RHR is up \(absValue)bpm from yesterday."))
            }
        }

        if parts.isEmpty {
            parts.append(String(localized: "Your condition score is \(data.conditionScore) today."))
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Today's Guide

    private static func guideTitle(for data: MorningBriefingData) -> String {
        data.recommendedIntensity
    }

    private static func guideMessage(for data: MorningBriefingData) -> String {
        var parts: [String] = []

        // Training recommendation
        if let trainingInsight = data.trainingInsight {
            parts.append(trainingInsight)
        } else {
            switch data.conditionStatus {
            case .excellent:
                parts.append(String(localized: "Great day for a challenging workout."))
            case .good:
                parts.append(String(localized: "A moderate workout fits your condition well."))
            case .fair:
                parts.append(String(localized: "Keep it light today to help recovery."))
            case .tired, .warning:
                parts.append(String(localized: "Focus on rest and gentle stretching."))
            }
        }

        // Recovery insight
        if let recoveryInsight = data.recoveryInsight {
            parts.append(recoveryInsight)
        }

        // Sleep debt advisory
        if let debtHours = data.sleepDebtHours, debtHours > 0.5 {
            let rounded = debtHours.formatted(.number.precision(.fractionLength(1)))
            parts.append(String(localized: "Sleep debt: \(rounded)h — try sleeping earlier tonight."))
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Weekly Context

    private static func weeklyTitle(for data: MorningBriefingData) -> String {
        if let prevAvg = data.previousWeekAverage {
            let diff = data.weeklyAverage - prevAvg
            if diff > 0 {
                return String(localized: "Trending up this week")
            } else if diff < 0 {
                return String(localized: "Trending down this week")
            }
        }
        return String(localized: "Your week so far")
    }

    // MARK: - Weather

    private static func weatherTitle(for data: MorningBriefingData) -> String {
        guard let condition = data.weatherCondition else {
            return String(localized: "Weather")
        }
        if let temp = data.temperature {
            let formatted = Int(temp)
            return "\(condition) \(formatted)°"
        }
        return condition
    }

    private static func weatherMessage(for data: MorningBriefingData) -> String {
        if let weatherInsight = data.weatherInsight {
            return weatherInsight
        }

        guard let fitness = data.outdoorFitnessLevel else {
            return String(localized: "Check weather conditions before heading out.")
        }

        return String(localized: "Outdoor fitness level: \(fitness).")
    }
}
