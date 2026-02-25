import Foundation

/// Intermediate values from body trend score calculation.
/// Mirrors ConditionScoreDetail pattern for UI debugging.
struct BodyScoreDetail: Sendable, Hashable {
    /// Weight change in kg over comparison window (negative = loss)
    let weightChange: Double?
    /// Body fat percentage change over comparison window (negative = loss)
    let bodyFatChange: Double?
    /// Points from weight component (max ±25)
    let weightPoints: Double
    /// Points from body fat component (max ±25)
    let bodyFatPoints: Double
    /// Neutral baseline before adjustments
    let baselinePoints: Double
    /// Final score after clamping [0–100]
    let finalScore: Int
}
