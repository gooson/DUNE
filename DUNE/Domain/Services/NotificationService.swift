import Foundation

/// Abstraction for local notification delivery.
/// Domain layer protocol — implementation uses UNUserNotificationCenter.
protocol NotificationService: Sendable {
    /// Requests notification authorization from the user. Returns true if granted.
    func requestAuthorization() async -> Bool

    /// Returns whether notifications are currently authorized.
    func isAuthorized() async -> Bool

    /// Sends a local notification for the given health insight.
    func send(_ insight: HealthInsight) async
}
