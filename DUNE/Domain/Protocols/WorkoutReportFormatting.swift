import Foundation

/// Generates a natural language summary from a WorkoutReport.
/// Conformers may use Foundation Models (on supported devices) or template strings.
protocol WorkoutReportFormatting: Sendable {
    func format(report: WorkoutReport) async -> String
}
