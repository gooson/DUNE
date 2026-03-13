import Foundation

/// Template-based text generation for morning briefing sections.
/// Produces localized text from MorningBriefingData without external dependencies.
enum BriefingTemplateEngine {
    struct Sections: Sendable {
        let recoveryTitle: String
        let recoveryMessage: String
        let guideTitle: String
        let guideMessage: String
        let weeklyTitle: String
        let weeklyMessage: String
        let weatherTitle: String?
        let weatherMessage: String?
    }

    static func generate(from data: MorningBriefingData) -> Sections {
        Sections(
            recoveryTitle: recoveryTitle(for: data),
            recoveryMessage: recoveryMessage(for: data),
            guideTitle: guideTitle(for: data),
            guideMessage: guideMessage(for: data),
            weeklyTitle: weeklyTitle(for: data),
            weeklyMessage: weeklyMessage(for: data),
            weatherTitle: data.hasWeatherData ? weatherTitle(for: data) : nil,
            weatherMessage: data.hasWeatherData ? weatherMessage(for: data) : nil
        )
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

        if let sleepMinutes = data.sleepDurationMinutes, sleepMinutes >= 0 {
            let hours = Int(sleepMinutes) / 60
            let mins = Int(sleepMinutes) % 60
            if mins > 0 {
                parts.append(String(localized: "You slept \(hours)h \(mins)m last night."))
            } else {
                parts.append(String(localized: "You slept \(hours) hours last night."))
            }
        }

        if let hrvDelta = data.hrvDelta {
            let absValue = Int(abs(hrvDelta))
            if hrvDelta > 0 {
                parts.append(String(localized: "HRV is up \(absValue)ms from yesterday."))
            } else if hrvDelta < 0 {
                parts.append(String(localized: "HRV is down \(absValue)ms from yesterday."))
            }
        }

        if let rhrDelta = data.rhrDelta {
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

    private static func weeklyMessage(for data: MorningBriefingData) -> String {
        var parts: [String] = []

        parts.append(String(localized: "Average condition: \(data.weeklyAverage) points."))

        let remaining = max(0, data.goalDays - data.activeDays)
        if remaining == 0 {
            parts.append(String(localized: "Weekly exercise goal completed!"))
        } else if data.activeDays > 0 {
            parts.append(String(localized: "\(data.activeDays)/\(data.goalDays) exercise days done, \(remaining) to go."))
        } else {
            parts.append(String(localized: "No workouts yet this week — start today!"))
        }

        return parts.joined(separator: " ")
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
