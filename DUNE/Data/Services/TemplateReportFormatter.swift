import Foundation

/// Template-based workout report formatter for devices without Foundation Models support.
struct TemplateReportFormatter: WorkoutReportFormatting, Sendable {

    func format(report: WorkoutReport) async -> String {
        let periodName = report.period == .weekly
            ? String(localized: "this week")
            : String(localized: "this month")

        var parts: [String] = []

        // Main stats sentence
        if report.stats.totalSessions > 0 {
            parts.append(String(localized: "You trained \(report.stats.activeDays) days \(periodName) with \(report.stats.totalSessions) sessions totaling \(Int(report.stats.totalVolume)) kg volume."))
        } else {
            return String(localized: "No workouts recorded \(periodName).")
        }

        // Volume change
        if let change = report.stats.volumeChangePercent {
            if change > 0.05 {
                parts.append(String(localized: "Volume is up \(Int(change * 100))% compared to last period."))
            } else if change < -0.05 {
                parts.append(String(localized: "Volume is down \(Int(abs(change) * 100))% compared to last period."))
            }
        }

        // Top muscle groups
        if !report.muscleBreakdown.isEmpty {
            let topNames = report.muscleBreakdown.prefix(2)
                .map(\.muscleGroup.displayName)
                .joined(separator: String(localized: " and "))
            parts.append(String(localized: "Most trained: \(topNames)."))
        }

        // Key highlight
        if let first = report.highlights.first {
            parts.append(first.description + ".")
        }

        return parts.joined(separator: " ")
    }
}
