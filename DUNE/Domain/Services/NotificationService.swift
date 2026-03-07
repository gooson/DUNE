import Foundation

/// Abstraction for local notification delivery.
/// Domain layer protocol — implementation uses UNUserNotificationCenter.
protocol NotificationService: Sendable {
    /// Requests notification authorization from the user.
    /// Returns true if granted and false if the user declined.
    func requestAuthorization() async throws -> Bool

    /// Returns whether notifications are currently authorized.
    func isAuthorized() async -> Bool

    /// Sends a local notification for the given health insight.
    func send(_ insight: HealthInsight) async

    /// Sends a local notification with a fixed identifier, replacing any previous notification with the same identifier.
    func send(_ insight: HealthInsight, replacingIdentifier: String) async
}
