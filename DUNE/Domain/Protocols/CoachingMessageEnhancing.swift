import Foundation

/// Enhances coaching insight messages with natural language generation.
/// Conformers may use Foundation Models (on supported devices) or return the original insight unchanged.
protocol CoachingMessageEnhancing: Sendable {
    /// Enhances the message text of the given insight using contextual data.
    /// Returns the original insight unchanged on failure or unsupported devices.
    func enhance(insight: CoachingInsight, context: CoachingInput) async -> CoachingInsight
}
