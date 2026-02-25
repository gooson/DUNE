import Foundation

/// Intermediate values from body trend score calculation.
/// Mirrors ConditionScoreDetail pattern for UI debugging.
struct BodyScoreDetail: Sendable, Hashable {
    /// Weight change in kg over comparison window (negative = loss)
    let weightChange: Double?
    /// Classification of weight trend (single source of truth from Domain)
    let weightLabel: TrendLabel
    /// Points from weight component (max ±25)
    let weightPoints: Double
    /// Neutral baseline before adjustments
    let baselinePoints: Double
    /// Final score after clamping [0–100]
    let finalScore: Int

    /// Domain-owned trend classification to avoid threshold duplication in Presentation.
    enum TrendLabel: String, Sendable, Hashable {
        case stable
        case losing
        case gaining
        case noData = "no data"
    }
}
