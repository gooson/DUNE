import Foundation

/// Represents a meaningful health insight that can trigger a local notification.
struct HealthInsight: Sendable {

    /// The type of health insight detected.
    enum InsightType: String, Sendable, CaseIterable, Codable {
        case hrvAnomaly
        case rhrAnomaly
        case sleepComplete
        case sleepDebt
        case stepGoal
        case weightUpdate
        case bodyFatUpdate
        case bmiUpdate
        case workoutPR
        case lifeChecklistReminder
    }

    /// Severity of the insight (determines notification priority).
    enum Severity: Sendable {
        case informational   // Sleep complete, weight update, etc.
        case attention        // HRV/RHR anomaly
        case celebration      // PR achieved, step goal hit
    }

    let type: InsightType
    let title: String
    let body: String
    let severity: Severity
    let date: Date
    let route: NotificationRoute?

    init(
        type: InsightType,
        title: String,
        body: String,
        severity: Severity,
        date: Date = Date(),
        route: NotificationRoute? = nil
    ) {
        self.type = type
        self.title = title
        self.body = body
        self.severity = severity
        self.date = date
        self.route = route
    }
}
